-- Administrador pode remover uma atividade cadastrada por engano (vagas já importadas não são afetadas).
create policy apagar on rh.atividade_etapa for delete to authenticated using (rh.e_admin());
grant delete on rh.atividade_etapa to authenticated;
