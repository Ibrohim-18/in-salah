export default async function(request) {
  const authHeader = request.headers.get('Authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return new Response(
      JSON.stringify({ error: 'Unauthorized' }),
      { status: 401, headers: { 'Content-Type': 'application/json' } }
    );
  }

  const baseUrl = 'https://fn43ntwx.us-east.insforge.app';

  const sessionResp = await fetch(`${baseUrl}/api/auth/sessions/current`, {
    headers: { 'Authorization': authHeader },
  });

  if (!sessionResp.ok) {
    return new Response(
      JSON.stringify({
        error: 'Please sign in to use translation.',
        code: 'auth_required',
      }),
      { status: 401, headers: { 'Content-Type': 'application/json' } }
    );
  }

  let body;
  try {
    body = await request.json();
  } catch {
    return new Response(
      JSON.stringify({ error: 'Invalid JSON' }),
      { status: 400, headers: { 'Content-Type': 'application/json' } }
    );
  }

  const text = (body.text || '').toString().trim();
  const targetLang = (body.target_lang || '').toString().trim();

  if (!text || !targetLang) {
    return new Response(
      JSON.stringify({ error: 'text and target_lang are required' }),
      { status: 400, headers: { 'Content-Type': 'application/json' } }
    );
  }

  if (text.length > 4000) {
    return new Response(
      JSON.stringify({ error: 'text too long (max 4000 chars)' }),
      { status: 400, headers: { 'Content-Type': 'application/json' } }
    );
  }

  const headers = {
    'Authorization': authHeader,
    'Content-Type': 'application/json',
  };

  const encoder = new TextEncoder();
  const hashBuffer = await crypto.subtle.digest('SHA-256', encoder.encode(text));
  const textHash = Array.from(new Uint8Array(hashBuffer))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');

  try {
    const cacheResp = await fetch(
      `${baseUrl}/api/database/records/translations_cache?text_hash=eq.${textHash}&target_lang=eq.${encodeURIComponent(targetLang)}&limit=1`,
      { headers }
    );
    if (cacheResp.ok) {
      const rows = await cacheResp.json();
      if (Array.isArray(rows) && rows.length > 0 && rows[0].translation) {
        return new Response(
          JSON.stringify({ translation: rows[0].translation, cached: true }),
          { status: 200, headers: { 'Content-Type': 'application/json' } }
        );
      }
    }
  } catch (_) {
    // cache miss on error, proceed to AI
  }

  const aiResp = await fetch(`${baseUrl}/api/ai/chat/completion`, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      model: 'openai/gpt-4o-mini',
      temperature: 0.1,
      maxTokens: 2000,
      messages: [
        {
          role: 'system',
          content: 'You are a professional translator. Translate the user message to the requested target language. Output ONLY the translation text — no explanations, no quotes, no language labels, no prefixes. Preserve line breaks. For Islamic religious content (duas, Quran verses, prayers), use respectful and accurate terminology commonly used by Muslims in the target language.'
        },
        {
          role: 'user',
          content: `Target language: ${targetLang}\n\nText to translate:\n${text}`
        }
      ]
    })
  });

  if (!aiResp.ok) {
    const err = await aiResp.text().catch(() => '');
    return new Response(
      JSON.stringify({ error: 'Translation service unavailable', details: err }),
      { status: 502, headers: { 'Content-Type': 'application/json' } }
    );
  }

  const aiData = await aiResp.json();
  const translation = ((aiData && aiData.text) || '').trim();

  if (!translation) {
    return new Response(
      JSON.stringify({ error: 'Empty translation received' }),
      { status: 502, headers: { 'Content-Type': 'application/json' } }
    );
  }

  try {
    await fetch(`${baseUrl}/api/database/records/translations_cache`, {
      method: 'POST',
      headers: { ...headers, 'Prefer': 'resolution=merge-duplicates' },
      body: JSON.stringify([{
        text_hash: textHash,
        target_lang: targetLang,
        translation,
      }]),
    });
  } catch (_) {
    // cache write is best-effort
  }

  return new Response(
    JSON.stringify({ translation, cached: false }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  );
}
