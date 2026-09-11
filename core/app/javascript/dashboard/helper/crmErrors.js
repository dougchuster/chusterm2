/**
 * A mensagem que o servidor mandou, quando ele mandou uma.
 *
 * O CRM tem dois formatos de erro em circulação (`error` e `message`); a
 * página não deveria precisar saber disso em cada `catch`. A API Rails
 * renderiza `{ error: ... }`, então `error` tem prioridade.
 */
export const messageFrom = (exception, fallback) =>
  exception?.response?.data?.error ||
  exception?.response?.data?.message ||
  fallback;
