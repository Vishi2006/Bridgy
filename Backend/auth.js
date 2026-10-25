// Supabase JWT gate for wallet routes.
//
// The token is validated by Supabase Auth on every request; a missing or
// expired token is a 401, never an anonymous fallback.

export function requireUser(supabase) {
  return async function authGate(req, res, next) {
    const header = req.get('authorization') || '';
    if (!header.startsWith('Bearer ')) {
      return res.status(401).json({
        error: 'Sign in required: missing bearer token',
        code: 'UNAUTHORIZED',
      });
    }

    const token = header.slice('Bearer '.length).trim();
    if (!token) {
      return res.status(401).json({
        error: 'Sign in required: empty bearer token',
        code: 'UNAUTHORIZED',
      });
    }

    let result;
    try {
      result = await supabase.auth.getUser(token);
    } catch (error) {
      return res.status(502).json({
        error: error.message,
        code: 'AUTH_UNAVAILABLE',
      });
    }

    const { data, error } = result;
    if (error || !data?.user) {
      return res.status(401).json({
        error: error?.message || 'Invalid or expired session',
        code: 'UNAUTHORIZED',
      });
    }

    req.user = data.user;
    req.accessToken = token;
    return next();
  };
}
