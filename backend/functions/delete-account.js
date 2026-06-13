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

  // Delete user data from database tables (RLS scopes these to the caller)
  await Promise.allSettled([
    fetch(`${baseUrl}/api/database/records/missed_prayers_log?user_id=eq.${userId}`, {
      method: 'DELETE',
      headers,
    }),
    fetch(`${baseUrl}/api/database/records/user_profiles?id=eq.${userId}`, {
      method: 'DELETE',
      headers,
    }),
  ]);

  // Delete the auth user via the admin endpoint. The admin key is read from the
  // project's reserved API_KEY env secret — never from the request — so it is
  // never shipped in the mobile app bundle.
  const adminKey = Deno.env.get('API_KEY');
  let authDeleted = false;
  if (adminKey) {
    const delResp = await fetch(`${baseUrl}/api/auth/users`, {
      method: 'DELETE',
      headers: {
        'Authorization': `Bearer ${adminKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ userIds: [userId] }),
    });
    authDeleted = delResp.ok;
  }

  return new Response(
    JSON.stringify({
      success: true,
      authDeleted,
      message: authDeleted
        ? 'Account deleted'
        : 'Account data deleted; auth user not removed (API_KEY unavailable)',
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  );
}
