/**
 * A mensagem que o servidor mandou, quando ele mandou uma.
 *
 * O CRM tem dois formatos de erro em circulação (`message` e `error`); a
 * página não deveria precisar saber disso em cada `catch`.
 */
export const messageFrom = (exception, fallback) =>
  exception?.response?.data?.message ||
  exception?.response?.data?.error ||
  fallback;
