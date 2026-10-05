-- Discriminação do uniforme por tipo (o termo em PDF lista cada item).
-- Entregas antigas ficam com 0/0/0 e continuam usando "quantidade" + "itens" (texto livre).
alter table rh.entregas_uniforme
  add column qtd_camisas int not null default 0 check (qtd_camisas between 0 and 99),
  add column qtd_calcas  int not null default 0 check (qtd_calcas  between 0 and 99),
  add column qtd_blusas  int not null default 0 check (qtd_blusas  between 0 and 99),
  add constraint entregas_uniforme_soma check (
    qtd_camisas + qtd_calcas + qtd_blusas = 0 or qtd_camisas + qtd_calcas + qtd_blusas = quantidade);
