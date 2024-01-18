--Процедура расчета данных для витрины оборотов dm.dm_account_turnover_f за выбранный день.
create or replace procedure dm.fill_account_turnover_f(i_OnDate date)
language plpgsql    
as $$
declare
	
begin	
	-- Удаляем данные если есть
	delete
		from dm.dm_account_turnover_f f
		where f.on_date = i_OnDate;
	-- выбираем данные в которые будем вставлять данные
	insert
	  into dm.dm_account_turnover_f
		(on_date,
		account_rk,
		credit_amount,
		credit_amount_thousands,
		debet_amount,
		debet_amount_thousands)
	-- Создаем временную таблицу, именованный подзапрос, с помощью конструкции with as
	-- В этой таблице происходят основные расчеты
	with wt_turn as
	-- Здесь мы собираем данные по кредиту из различных таблиц
		(select 
			p.credit_account_rk                  				as account_rk,
			p.credit_amount                      				as credit_amount,
			(p.credit_amount * coalesce(er.reduced_cource, 1) / 1000)	as credit_amount_thousands,
			cast(null as numeric)                 				as debet_amount,
			cast(null as numeric)                 				as debet_amount_thousands
		 -- Здесь происходят джоины разных файлов по ID(RK) и по дате
	    from ds.ft_posting_f p
	    join ds.md_account_d a
	      on a.account_rk = p.credit_account_rk
	    left
	    join ds.md_exchange_rate_d er
	      on er.currency_rk = a.currency_rk
	     and i_OnDate 
	     	between er.data_actual_date 
	     	and er.data_actual_end_date
		 -- Здесь ограничивается дата по переданной переменной
	   where p.oper_date = i_OnDate
	     and i_OnDate 
	     	between a.data_actual_date 
	     	and a.data_actual_end_date
	     and a.data_actual_date 
	     	between date_trunc('month', i_OnDate) 
	     	and (date_trunc('MONTH', i_OnDate) + INTERVAL '1 MONTH - 1 day')
		union all
		-- и соеденяем с данными по дебету так же из различных таблиц
		select 
			p.debet_account_rk                  				as account_rk,
			cast(null as numeric)								as credit_amount,
			cast(null as numeric)                 				as credit_amount_thousands,
			p.debet_amount                       				as debet_amount,
			(p.debet_amount * coalesce(er.reduced_cource, 1) / 1000)		as debet_amount_thousands
	    from ds.ft_posting_f p
	    join ds.md_account_d a
	      on a.account_rk = p.debet_account_rk
	    left 
	    join ds.md_exchange_rate_d er
	      on er.currency_rk = a.currency_rk
	     and i_OnDate between er.data_actual_date 
	     	 and er.data_actual_end_date
	   where p.oper_date = i_OnDate
	     and i_OnDate between a.data_actual_date 
	     	and a.data_actual_end_date
	     and a.data_actual_date between date_trunc('month', i_OnDate) 
	     	 and (date_trunc('MONTH', i_OnDate) + INTERVAL '1 MONTH - 1 day'))
		-- Здесь виртуальная таблица заканчивается
		-- И мы начинаем суммировать значения по account_rk которые прежде объеденили
	select 
		i_OnDate    				                        	as on_date,
		t.account_rk,
		sum(coalesce(t.credit_amount, 0))                   	as credit_amount,
		sum(coalesce(t.credit_amount_thousands, 0))               	as credit_amount_thousands,
		sum(coalesce(t.debet_amount, 0))                    	as debet_amount,
		sum(coalesce(t.debet_amount_thousands, 0))                	as debet_amount_thousands
	from wt_turn t
	group by t.account_rk;

commit;	
end;$$;

--Расчет витрины оборотов dm.dm_account_turnover_f за месяц.
create or replace procedure dm.month_account_turnover_f(i_OnDate date)
language plpgsql    
as $$
declare
	-- Здесь мы объявляем переменные для цикла
	start_date date := date_trunc('month',i_OnDate);
	end_date date := date_trunc('month',i_OnDate) + interval '1 MONTH - 1 day';
begin
	-- Здесь происходит цикл который вызывает процедуру описанную выше пока start date не станет больше end date
	while start_date <= end_date loop
		call dm.fill_account_turnover_f(start_date);
		start_date := start_date + interval '1 day';
	end loop;
commit;  	
end;$$;