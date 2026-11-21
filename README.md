# Disciplina Diária — Cloud

PWA compartilhada para iPhone, Android e desktop. Usa Supabase (Postgres + Auth). O administrador cria e altera atividades e registros; usuários convidados têm permissão somente de leitura. Todos veem a mesma checklist e o mesmo histórico.

## Arquivos
- `index.html`: aplicação web.
- `config.js.example`: modelo de configuração. Copie para `config.js`.
- `supabase-schema.sql`: tabelas, funções e políticas RLS.
- `manifest.json`, `sw.js`, `icon.svg`: instalação PWA.

## Configuração do Supabase (gratuito)
1. Crie um projeto em https://supabase.com/ (plano Free).
2. No SQL Editor, execute todo o conteúdo de `supabase-schema.sql`.
3. Em Project Settings → API, copie Project URL e anon/public key.
4. Copie `config.js.example` para `config.js` e preencha os dois valores. A chave `anon`/`publishable` pode ficar no navegador; nunca coloque `service_role`/secret key no frontend.
5. Publique todos os arquivos, incluindo `config.js`, em hospedagem HTTPS estática, por exemplo GitHub Pages.
6. Abra o endereço no Safari do iPhone e crie a conta principal. Confirme o e-mail se o Supabase solicitar. O primeiro login sem tracker cria o tracker e as 11 atividades iniciais.

## Convidar visualizador
1. No Supabase Dashboard → Authentication → Users, use **Invite user** e envie o convite ao e-mail da pessoa.
2. Depois que a pessoa aceitar e criar a conta, entre na aplicação como administrador.
3. Abra Atividades → Convidar alguém para visualizar e informe o mesmo e-mail.
4. O usuário convidado entra com a própria conta e terá acesso somente de leitura ao tracker compartilhado.

## Segurança e comportamento
- RLS está habilitado em todas as tabelas.
- A role `owner` pode alterar atividades e registros; `viewer` só pode ler.
- Não compartilhe a `service_role` key. A chave pública `anon`/publishable é a correta para o browser.
- Todas as novas atividades começam como não feitas quando não existe registro daquele dia.
- A tela inicial sempre abre na data atual; histórico permite consultar datas anteriores.
- O banco é compartilhado e centralizado. Recomenda-se exportar backup JSON periodicamente.

## Limitações desta versão
- O convite de usuário é iniciado pelo painel Supabase; a aplicação associa ao tracker uma conta já criada/convite já enviado.
- A primeira publicação requer configurar o projeto Supabase e as credenciais em `config.js`. Isso não pode ser feito sem acesso à sua conta/projeto.
- O service worker oferece shell offline, mas gravações e sincronização exigem conexão com a internet.
