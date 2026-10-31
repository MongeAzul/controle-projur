// Ligação com o banco de dados do Supabase.
// Copie os dois valores de: Supabase > Project Settings > API (ou Data API).
// A chave "anon public" é feita para ficar na página: o que protege os dados são as
// regras de acesso de supabase/schema.sql (só e-mails cadastrados em "membros" veem algo).
// NUNCA coloque aqui a chave "service_role".
window.PROJUR_CONFIG = {
  supabaseUrl: "https://twdalfjcgbquhvhqmxuu.supabase.co",
  supabaseAnonKey: "sb_publishable_SE4aDoSYtOH_uP2zapVySw_lCdMOwBL"
};
