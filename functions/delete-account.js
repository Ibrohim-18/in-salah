export default async function(request) {
  const authHeader = request.headers.get('Authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return new Response(
      JSON.stringify({ error: 'Unauthorized' }),
      { status: 401, headers: { 'Content-Type': 'application/json' } }
    );
  }

  const accessToken = authHeader.replace('Bearer ', '');
  const baseUrl = 'https://fn43ntwx.us-east.insforge.app';

  // Verify the user's session
  const sessionResp = await fetch(`${baseUrl}/api/auth/sessions/current`, {
    headers: { 'Authorization': `Bearer ${accessToken}` },
  });

  if (!sessionResp.ok) {
    return new Response(
      JSON.stringify({ error: 'Invalid session' }),
      { status: 401, headers: { 'Content-Type': 'application/json' } }
    );
  }

  const session = await sessionResp.json();
  const userId = session.user?.id;

  if (!userId) {
    return new Response(
      JSON.stringify({ error: 'User not found in session' }),
      { status: 400, headers: { 'Content-Type': 'application/json' } }
    );
  }

  const headers = {
    'Authorization': `Bearer ${accessToken}`,
    'Content-Type': 'application/json',
  };

  // Delete user data from database tables
  const deletions = await Promise.allSettled([
    fetch(`${baseUrl}/api/database/records/missed_prayers_log?user_id=eq.${userId}`, {
      method: 'DELETE',
      headers,
    }),
    fetch(`${baseUrl}/api/database/records/user_profiles?id=eq.${userId}`, {
      method: 'DELETE',
      headers,
    }),
  ]);

  // Delete the auth user (admin endpoint)
  const apiKey = request.headers.get('X-API-Key');
  if (apiKey) {
    await fetch(`${baseUrl}/api/auth/users`, {
      method: 'DELETE',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ userIds: [userId] }),
    });
  }

  return new Response(
    JSON.stringify({ success: true, message: 'Account deleted' }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  );
}
