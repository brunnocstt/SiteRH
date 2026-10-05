-- Só entram processos de filiais cadastradas; os demais são descartados na importação.
do $$
declare d text;
begin
  d := pg_get_functiondef('rh.importar_processos(jsonb,text)'::regprocedure);
  d := replace(d, 'if fil is null then sem_filial := sem_filial + 1; end if;', 'if fil is null then sem_filial := sem_filial + 1; continue; end if;');
  if d not like '%sem_filial + 1; continue;%' then raise exception 'trecho não encontrado'; end if;
  execute d;
end $$;
