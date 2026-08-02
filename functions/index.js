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
        const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });
        const result = await model.generateContent(prompt);
        return { text: result.response.text() };
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
 */
exports.generateAIImage = onCall({ secrets: [OPENAI_API_KEY] }, async (request) => {
    const prompt = request.data.prompt;

    if (!prompt) {
        throw new Error("Prompt is required");
    }

    try {
        const openai = new OpenAI({ apiKey: OPENAI_API_KEY.value() });
        const response = await openai.images.generate({
            model: "dall-e-3",
            prompt: prompt,
            n: 1,
            size: "1024x1024",
        });

        return { url: response.data[0].url };
    } catch (e) {
        console.error("Image generation failed:", e);
        throw new Error(e.message || "Image generation failed");
    }
});
