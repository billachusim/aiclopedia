const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { GoogleGenerativeAI } = require("@google/generative-ai");
const OpenAI = require("openai");

// Define Secrets
const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");
const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");

/**
 * Handles AI Text Generation requests.
 * Tries Gemini first, falls back to OpenAI.
 */
exports.getAIResponse = onCall({ secrets: [GEMINI_API_KEY, OPENAI_API_KEY] }, async (request) => {
    const prompt = request.data.prompt;

    if (!prompt) {
        throw new HttpsError("invalid-argument", "Prompt is required");
    }

    // 1. Try Gemini
    try {
        const genAI = new GoogleGenerativeAI(GEMINI_API_KEY.value());

        // Cost optimization: Use Lite model for simple questions (under 100 chars)
        const isSimple = prompt.length < 100;
        const modelName = isSimple ? "gemini-3.5-flash-lite" : "gemini-3.5-flash";

        const model = genAI.getGenerativeModel({ model: modelName });
        const result = await model.generateContent(prompt);
        return { text: result.response.text(), model: modelName };
    } catch (e) {
        console.error("Gemini failed, falling back to OpenAI:", e);
    }

    // 2. Fallback to OpenAI
    try {
        const openai = new OpenAI({ apiKey: OPENAI_API_KEY.value() });
        const completion = await openai.chat.completions.create({
            model: "gpt-4o-mini",
            messages: [{ role: "user", content: prompt }],
        });
        return { text: completion.choices[0].message.content };
    } catch (e) {
        console.error("OpenAI also failed:", e);
        // If both fail, throw a descriptive HttpsError
        if (e.code === 'insufficient_quota' || e.code === 'credit_balance_exhausted') {
            throw new HttpsError("unavailable", "AI quota exhausted. Please try again later.");
        }
        throw new HttpsError("internal", "AI services unavailable");
    }
});

/**
 * Handles AI Image Generation requests.
 * Tries Gemini (image model) first, falls back to OpenAI.
 * The image is saved to Firebase Storage so the returned URL never expires
 * (OpenAI URLs expire after ~1 hour, which broke cached images).
 */
const admin = require("firebase-admin");
const crypto = require("crypto");
if (!admin.apps.length) admin.initializeApp();

async function saveImageToStorage(base64Data, mimeType) {
    const bucket = admin.storage().bucket();
    const token = crypto.randomUUID();
    const ext = mimeType === "image/jpeg" ? "jpg" : "png";
    const path = `generated_images/${Date.now()}_${token}.${ext}`;
    await bucket.file(path).save(Buffer.from(base64Data, "base64"), {
        metadata: {
            contentType: mimeType,
            metadata: { firebaseStorageDownloadTokens: token },
        },
    });
    return `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(path)}?alt=media&token=${token}`;
}

async function generateWithGemini(apiKey, prompt) {
    const res = await fetch(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-image:generateContent",
        {
            method: "POST",
            headers: { "Content-Type": "application/json", "x-goog-api-key": apiKey },
            body: JSON.stringify({
                contents: [{ parts: [{ text: prompt }] }],
                generationConfig: { responseModalities: ["IMAGE"] },
            }),
        }
    );
    const body = await res.json();
    if (!res.ok) {
        throw new Error(`Gemini image ${res.status}: ${body?.error?.message || "unknown error"}`);
    }
    const parts = body?.candidates?.[0]?.content?.parts || [];
    const img = parts.find((p) => p.inlineData && p.inlineData.data);
    if (!img) throw new Error("Gemini returned no image (possibly blocked by safety filters)");
    return { data: img.inlineData.data, mimeType: img.inlineData.mimeType || "image/png" };
}

async function generateWithOpenAI(apiKey, prompt) {
    const openai = new OpenAI({ apiKey });
    const response = await openai.images.generate({
        model: "gpt-image-1",
        prompt: prompt,
        n: 1,
        size: "1024x1024",
    });
    return { data: response.data[0].b64_json, mimeType: "image/png" };
}

exports.generateAIImage = onCall(
    { secrets: [GEMINI_API_KEY, OPENAI_API_KEY], timeoutSeconds: 120, memory: "512MiB" },
    async (request) => {
        const prompt = (request.data && request.data.prompt || "").trim();
        if (!prompt) {
            throw new HttpsError("invalid-argument", "Prompt is required");
        }

        let image = null;
        try {
            image = await generateWithGemini(GEMINI_API_KEY.value(), prompt);
        } catch (e) {
            console.error("Gemini image failed, falling back to OpenAI:", e);
        }

        if (!image) {
            try {
                image = await generateWithOpenAI(OPENAI_API_KEY.value(), prompt);
            } catch (e) {
                console.error("OpenAI image also failed:", e);
                if (e.code === "content_policy_violation" || e.code === "moderation_blocked") {
                    throw new HttpsError("failed-precondition", "This prompt can't be turned into an image. Try rewording it.");
                }
                throw new HttpsError("unavailable", "Image generation is temporarily unavailable. Please try again later.");
            }
        }

        try {
            const url = await saveImageToStorage(image.data, image.mimeType);
            return { url };
        } catch (e) {
            console.error("Saving image failed:", e);
            throw new HttpsError("unavailable", "Image generation is temporarily unavailable. Please try again later.");
        }
    }
);
