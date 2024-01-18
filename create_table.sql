CALL dm.fill_account_turnover_f('2018-01-09');
CALL dm.month_account_turnover_f('2018-01-01');

CALL dm.fill_f101_round_f('2018-01-31');

SELECT * FROM dm.dm_account_turnover_f
SELECT * FROM dm.dm_f101_round_f

create table if not exists dm.dm_f101_round_f (
	regn numeric(4),
	chapter char(1),
	ledger_account char(5),
	characteristic char(1),
	balance_in_rub numeric(16),
	balance_in_curr numeric(16),
	balance_in_total numeric(33,4),
	turn_deb_rub numeric(16),
	turn_deb_curr numeric(16),
	turn_deb_total numeric(33,4),
	turn_cre_rub numeric(16),
	turn_cre_curr numeric(16),
	turn_cre_total numeric(33,4),
	balance_out_rub numeric(16),
	balance_out_curr numeric(16),
	balance_out_total numeric(33,4),
	from_date date,
	to_date date,
	priz numeric(1)
);

create table if not exists dm.dm_account_turnover_f (
	on_date date,
	account_rk numeric,
	credit_amount numeric(23,8),
	credit_amount_thousands numeric(23,8),
	debet_amount numeric(23,8),
	debet_amount_thousands numeric(23,8)
);


