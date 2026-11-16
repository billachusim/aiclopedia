#!/usr/bin/env node
/**
 * One-off cleanup for the `questions` collection (Firestore REST API).
 *
 *  - Questions whose answer is empty, a placeholder ("Tap open to load
 *    answer") or a saved error get `answerRefresh` set, which makes the
 *    `fillMissingAnswer` Cloud Function generate a real answer.
 *  - Dead image links (expired DALL·E blob URLs, random picsum placeholders)
 *    are cleared so the app offers "Generate AI Illustration" instead.
 *
 * Usage (needs an OAuth access token for an account that can edit the project,
 * e.g. the Firebase CLI's cached token):
 *   ACCESS_TOKEN=... node scripts/cleanup-answers.js            # dry run
 *   ACCESS_TOKEN=... node scripts/cleanup-answers.js --apply    # write
 * Options: --max=N (max answers to refresh, default 1500), --project=ID
 */
const args = Object.fromEntries(process.argv.slice(2).map((a) => {
    const [k, v] = a.replace(/^--/, "").split("=");
    return [k, v === undefined ? true : v];
}));
const PROJECT = args.project || "chat-gpt-for-students";
const APPLY = Boolean(args.apply);
const MAX_REFRESH = Number(args.max || 1500);
const TOKEN = process.env.ACCESS_TOKEN;
if (!TOKEN) {
    console.error("Set ACCESS_TOKEN first.");
    process.exit(1);
}
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;

const BAD_ANSWER_MARKERS = [
    "tap open to load answer", "ai model is currently unavailable", "failed to generate answer",
    "couldn't generate an answer", "couldn't answer right now", "firebase_functions/",
    "ai services unavailable", "ai quota exhausted", "ai service error", "unable to load",
];
function isUsableAnswer(answer) {
    if (typeof answer !== "string") return false;
    const text = answer.trim();
    if (text.length < 2) return false;
    const lower = text.toLowerCase();
    if (lower.startsWith("⚠️") || lower.startsWith("error:")) return false;
    return !BAD_ANSWER_MARKERS.some((m) => lower.includes(m));
}
function isDeadImage(url) {
    if (typeof url !== "string" || !url) return false;
    const lower = url.toLowerCase();
    return lower.includes("oaidalleapiprodscus.blob.core.windows.net") || lower.includes("picsum.photos");
}
const str = (f) => (f && (f.stringValue !== undefined ? f.stringValue : null));
const bool = (f) => (f && f.booleanValue === true);

async function api(url, opts = {}) {
    const res = await fetch(url, {
        ...opts,
        headers: { Authorization: `Bearer ${TOKEN}`, "Content-Type": "application/json", ...(opts.headers || {}) },
    });
    const body = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(`${res.status} ${JSON.stringify(body).slice(0, 300)}`);
    return body;
}

async function main() {
    const docs = [];
    let pageToken = "";
    do {
        const qs = new URLSearchParams({ pageSize: "300" });
        ["question", "answer", "imageUrl", "isFeatured", "isPublic", "timestamp"].forEach((f) => qs.append("mask.fieldPaths", f));
        if (pageToken) qs.set("pageToken", pageToken);
        const page = await api(`${BASE}/questions?${qs}`);
        docs.push(...(page.documents || []));
        pageToken = page.nextPageToken || "";
    } while (pageToken);

    const rows = docs.map((d) => {
        const f = d.fields || {};
        return {
            name: d.name,
            id: d.name.split("/").pop(),
            question: str(f.question) || "",
            answer: str(f.answer),
            imageUrl: str(f.imageUrl),
            featured: bool(f.isFeatured),
            isPublic: !(f.isPublic && f.isPublic.booleanValue === false),
            ts: (f.timestamp && f.timestamp.timestampValue) || "",
        };
    });

    // Featured first, then public, then newest.
    const needsAnswer = rows
        .filter((r) => r.question.trim() && !isUsableAnswer(r.answer))
        .sort((a, b) => (b.featured - a.featured) || (b.isPublic - a.isPublic) || b.ts.localeCompare(a.ts));
    const toRefresh = needsAnswer.slice(0, MAX_REFRESH);
    const deadImages = rows.filter((r) => isDeadImage(r.imageUrl));

    console.log(`Total questions: ${rows.length}`);
    console.log(`Need an answer: ${needsAnswer.length} (featured ${needsAnswer.filter((r) => r.featured).length}), refreshing ${toRefresh.length}`);
    console.log(`Dead image links: ${deadImages.length}`);
    if (!APPLY) {
        console.log("Dry run. Re-run with --apply to write.");
        return;
    }

    const now = new Date().toISOString();
    let done = 0;
    for (const r of deadImages) {
        await api(`${r.name.replace(/^projects\/[^/]+\/databases\/\(default\)\/documents/, BASE)}?updateMask.fieldPaths=imageUrl`, {
            method: "PATCH",
            body: JSON.stringify({ fields: { imageUrl: { stringValue: "" } } }),
        });
        done++;
    }
    console.log(`Cleared ${done} dead image links.`);

    done = 0;
    for (const r of toRefresh) {
        await api(`${r.name.replace(/^projects\/[^/]+\/databases\/\(default\)\/documents/, BASE)}?updateMask.fieldPaths=answerRefresh`, {
            method: "PATCH",
            body: JSON.stringify({ fields: { answerRefresh: { stringValue: now } } }),
        });
        done++;
        if (done % 50 === 0) {
            console.log(`Requested ${done}/${toRefresh.length} answers…`);
            await new Promise((r) => setTimeout(r, 5000)); // pace the AI calls
        }
    }
    console.log(`Requested ${done} answers. The fillMissingAnswer function fills them over the next few minutes.`);
}

main().catch((e) => {
    console.error(e);
    process.exit(1);
});
