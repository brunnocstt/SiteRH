-- Remove TODOS os dados fictícios ([DEMO]) criados por demo_dados_ficticios.sql.
-- Não toca em nada que não esteja marcado como demo.

delete from rh.entregas_uniforme where observacoes like '[DEMO]%';
delete from rh.documentos_acessos where documento_id in (select id from rh.documentos where descricao like '[DEMO]%');
delete from rh.documentos where descricao like '[DEMO]%';

delete from rh.conclusoes where curso_id in (select id from rh.cursos where nome like '[DEMO]%');
delete from rh.turma_participantes where turma_id in (select id from rh.turmas where observacoes = '[DEMO]');
delete from rh.turmas where observacoes = '[DEMO]';
delete from rh.pessoa_trilhas where trilha_id in (select id from rh.trilhas where nome like '[DEMO]%');
delete from rh.cursos where nome like '[DEMO]%';     -- apaga exigências e vínculos de trilha em cascata
delete from rh.trilhas where nome like '[DEMO]%';

delete from rh.vagas where observacoes like '[DEMO]%';   -- apaga o histórico em cascata
