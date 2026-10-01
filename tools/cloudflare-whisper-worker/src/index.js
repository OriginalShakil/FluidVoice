/**
 * Cloudflare Workers AI Whisper Large v3 Turbo OpenAI-Compatible API Proxy
 *
 * Exposes a standard OpenAI-compatible `/v1/audio/transcriptions` endpoint
 * powered by `@cf/openai/whisper-large-v3-turbo`.
 *
 * Fully supports Bengali / Bangla (`bn`) and 90+ languages with auto-detection.
 */

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

export default {
  async fetch(request, env, ctx) {
    // 1. Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: CORS_HEADERS });
    }

    const url = new URL(request.url);

    // 2. Health check route
    if (url.pathname === '/' || url.pathname === '/health') {
      return Response.json(
        {
          status: 'ok',
          service: 'Cloudflare Workers AI Whisper Large v3 Turbo',
          model: '@cf/openai/whisper-large-v3-turbo',
          endpoint: '/v1/audio/transcriptions',
          supportedLanguages: ['bn', 'auto', 'en', 'es', 'fr', 'de', '90+ more'],
        },
        { headers: CORS_HEADERS }
      );
    }

    // 3. Transcription route (/v1/audio/transcriptions or /transcribe)
    if (url.pathname.endsWith('/audio/transcriptions') || url.pathname.endsWith('/transcribe')) {
      if (request.method !== 'POST') {
        return Response.json(
          { error: { message: 'Method not allowed. Use POST.' } },
          { status: 405, headers: CORS_HEADERS }
        );
      }

      // Optional Auth Token check
      if (env.AUTH_TOKEN) {
        const auth = request.headers.get('Authorization');
        const token = auth?.replace(/^Bearer\s+/i, '');
        if (token !== env.AUTH_TOKEN) {
          return Response.json(
            { error: { message: 'Unauthorized. Invalid Bearer token.' } },
            { status: 401, headers: CORS_HEADERS }
          );
        }
      }

      try {
        const contentType = request.headers.get('content-type') || '';
        let audioBytes;
        let language = null;

        if (contentType.includes('multipart/form-data')) {
          // Standard OpenAI client format (FormData with 'file', 'language', etc.)
          const formData = await request.formData();
          const file = formData.get('file');
          if (!file) {
            return Response.json(
              { error: { message: "Missing required 'file' parameter in multipart form." } },
              { status: 400, headers: CORS_HEADERS }
            );
          }
          language = formData.get('language');
          const arrayBuffer = await file.arrayBuffer();
          audioBytes = new Uint8Array(arrayBuffer);
        } else if (contentType.includes('application/json')) {
          // JSON payload format with base64 audio
          const body = await request.json();
          if (!body.audio) {
            return Response.json(
              { error: { message: "Missing 'audio' base64 string in JSON body." } },
              { status: 400, headers: CORS_HEADERS }
            );
          }
          language = body.language;
          const binaryStr = atob(body.audio);
          const bytes = new Uint8Array(binaryStr.length);
          for (let i = 0; i < binaryStr.length; i++) {
            bytes[i] = binaryStr.charCodeAt(i);
          }
          audioBytes = bytes;
        } else {
          // Raw binary audio stream
          const arrayBuffer = await request.arrayBuffer();
          audioBytes = new Uint8Array(arrayBuffer);
          const urlLang = url.searchParams.get('language');
          if (urlLang) language = urlLang;
        }

        if (!audioBytes || audioBytes.length === 0) {
          return Response.json(
            { error: { message: 'Received empty audio payload.' } },
            { status: 400, headers: CORS_HEADERS }
          );
        }

        // Configure inference options
        const aiParams = {
          audio: [...audioBytes],
        };

        // If language specified and not 'auto', enforce it (e.g. 'bn' for Bangla)
        if (language && language.toLowerCase() !== 'auto' && language.trim().length > 0) {
          aiParams.language = language.trim().toLowerCase();
        }

        // Run Cloudflare Workers AI Whisper Large v3 Turbo
        const result = await env.AI.run('@cf/openai/whisper-large-v3-turbo', aiParams);

        // Return standard OpenAI-compatible response format
        return Response.json(
          {
            text: result.text || '',
            language: language || 'auto',
            task: 'transcribe',
          },
          { headers: CORS_HEADERS }
        );
      } catch (err) {
        return Response.json(
          { error: { message: err.message || 'Workers AI Whisper transcription failed.' } },
          { status: 500, headers: CORS_HEADERS }
        );
      }
    }

    return Response.json(
      { error: { message: `Route not found: ${url.pathname}` } },
      { status: 404, headers: CORS_HEADERS }
    );
  },
};
