const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { GoogleGenerativeAI } = require("@google/generative-ai");
const OpenAI = require("openai");
const admin = require("firebase-admin");
if (!admin.apps.length) admin.initializeApp();

// Define Secrets
const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");
const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");

const SYSTEM_INSTRUCTION = [
    "You are Ai Clopedia, a friendly and accurate encyclopedia assistant.",
    "Answer the user's question directly in the first sentence, then add helpful detail.",
    "Format with Markdown: short paragraphs, **bold** key terms, and bullet points or",
    "numbered steps where they help. Use a heading only for long answers.",
    "Keep answers under about 350 words unless the user asks for more.",
    "Never say you are 'an AI language model'. If something is uncertain, say so briefly.",
].join(" ");

// Text that older app versions saved as an "answer" but is not a real answer.
const BAD_ANSWER_MARKERS = [
    "tap open to load answer",
    "ai model is currently unavailable",
    "failed to generate answer",
    "couldn't generate an answer",
    "couldn't answer right now",
    "firebase_functions/",
    "ai services unavailable",
    "ai quota exhausted",
    "ai service error",
    "unable to load",
];

function isUsableAnswer(answer) {
    if (typeof answer !== "string") return false;
    const text = answer.trim();
    if (text.length < 2) return false;
    const lower = text.toLowerCase();
    if (lower.startsWith("⚠️") || lower.startsWith("error:")) return false;
    return !BAD_ANSWER_MARKERS.some((m) => lower.includes(m));
}

/**
 * Generates an answer. Tries Gemini first, falls back to OpenAI.
 * Throws an HttpsError when both fail.
 */
async function generateAnswerText(prompt) {
    // 1. Try Gemini
    try {
        const genAI = new GoogleGenerativeAI(GEMINI_API_KEY.value());

        // Cost optimization: Use Lite model for simple questions (under 100 chars)
        const isSimple = prompt.length < 100;
        const modelName = isSimple ? "gemini-3.5-flash-lite" : "gemini-3.5-flash";

        const model = genAI.getGenerativeModel({ model: modelName, systemInstruction: SYSTEM_INSTRUCTION });
        const result = await model.generateContent(prompt);
        const text = result.response.text();
        if (text && text.trim()) return { text, model: modelName };
        throw new Error("Gemini returned an empty answer");
    } catch (e) {
        console.error("Gemini failed, falling back to OpenAI:", e);
    }

    // 2. Fallback to OpenAI
    try {
        const openai = new OpenAI({ apiKey: OPENAI_API_KEY.value() });
        const completion = await openai.chat.completions.create({
            model: "gpt-4o-mini",
            messages: [
                { role: "system", content: SYSTEM_INSTRUCTION },
                { role: "user", content: prompt },
            ],
        });
        return { text: completion.choices[0].message.content, model: "gpt-4o-mini" };
    } catch (e) {
        console.error("OpenAI also failed:", e);
        if (e.code === 'insufficient_quota' || e.code === 'credit_balance_exhausted') {
            throw new HttpsError("unavailable", "AI quota exhausted. Please try again later.");
        }
        throw new HttpsError("internal", "AI services unavailable");
    }
}

/**
 * Handles AI Text Generation requests from signed-in app users.
 */
exports.getAIResponse = onCall({ secrets: [GEMINI_API_KEY, OPENAI_API_KEY] }, async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "Please sign in to ask AiClopedia.");
    }
    const prompt = (request.data && request.data.prompt || "").toString().trim();

    if (!prompt) {
        throw new HttpsError("invalid-argument", "Prompt is required");
    }
    if (prompt.length > 4000) {
        throw new HttpsError("invalid-argument", "That question is too long. Please shorten it.");
    }

    return generateAnswerText(prompt);
});

/**
 * Makes sure every saved question ends up with a real answer, so the feed
 * and the details page can show it from Firestore without calling the AI.
 * - On create: fills the answer if the app didn't save one.
 * - On update: only when `answerRefresh` changes (set by the one-off cleanup
 *   script), so votes and other edits never trigger AI calls.
 */
exports.fillMissingAnswer = onDocumentWritten(
    { document: "questions/{questionId}", secrets: [GEMINI_API_KEY, OPENAI_API_KEY], timeoutSeconds: 120 },
    async (event) => {
        const after = event.data && event.data.after && event.data.after.exists ? event.data.after.data() : null;
        if (!after) return;
        const before = event.data.before && event.data.before.exists ? event.data.before.data() : null;

        const question = (after.question || "").toString().trim();
        if (!question || isUsableAnswer(after.answer)) return;

        const isCreate = !before;
        const refreshRequested = before && String(before.answerRefresh || "") !== String(after.answerRefresh || "");
        if (!isCreate && !refreshRequested) return;

        try {
            const { text, model } = await generateAnswerText(question.slice(0, 4000));
            if (!isUsableAnswer(text)) throw new Error("Generated text was not usable");
            await event.data.after.ref.set(
                { answer: text, answerModel: model || null, answerError: admin.firestore.FieldValue.delete() },
                { merge: true }
            );
        } catch (e) {
            console.error(`fillMissingAnswer failed for ${event.params.questionId}:`, e.message || e);
            await event.data.after.ref.set({ answerError: true }, { merge: true });
        }
    }
);

/**
 * Handles AI Image Generation requests.
 * Tries Gemini (image model) first, falls back to OpenAI.
 * The image is saved to Firebase Storage so the returned URL never expires
 * (OpenAI URLs expire after ~1 hour, which broke cached images).
 */
const crypto = require("crypto");

async function saveImageToStorage(base64Data, mimeType) {
    const bucket = admin.storage().bucket("chat-gpt-for-students.appspot.com");
    const token = crypto.randomUUID();
    const ext = mimeType === "image/jpeg" ? "jpg" : "png";
    const path = `generated_images/${Date.now()}_${token}.${ext}`;
    const file = bucket.file(path);
    await file.save(Buffer.from(base64Data, "base64"), {
        metadata: {
            contentType: mimeType,
            cacheControl: "public, max-age=31536000",
            metadata: { firebaseStorageDownloadTokens: token },
        },
    });
    // Generated images are shareable content, so serve them as public objects.
    // This avoids depending on the Firebase Storage service agent for token URLs.
    try {
        await file.makePublic();
        return `https://storage.googleapis.com/${bucket.name}/${path}`;
    } catch (e) {
        console.error("makePublic failed, falling back to token URL:", e.message);
        return `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(path)}?alt=media&token=${token}`;
    }
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
