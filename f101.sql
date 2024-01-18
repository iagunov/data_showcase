--Процедура расчета данных для витрины 101-й отчётной формы dm.dm_f101_round_f.
create or replace procedure dm.fill_f101_round_f(i_OnDate date)
language plpgsql    
as $$
declare	
begin
	-- Сначала удаляем данные из таблицы если они там есть
	delete
		from dm.DM_F101_ROUND_F f
		where from_date = date_trunc('month', i_OnDate)  
		and to_date = (date_trunc('MONTH', i_OnDate) + INTERVAL '1 MONTH - 1 day');
	
	-- далее мы выбираем столбцы таблицы куда будем вставлять данные как в классическом insert
	insert 
      into dm.dm_f101_round_f(
		    regn,         
			chapter,           
			ledger_account,    
			characteristic,    
			balance_in_rub,    
			balance_in_curr,    
			balance_in_total,  
			turn_deb_rub,      
			turn_deb_curr,      
			turn_deb_total,    
			turn_cre_rub,      
			turn_cre_curr,      
			turn_cre_total,    
			balance_out_rub,  
			balance_out_curr,   
			balance_out_total,
		  	from_date,         
			to_date,  
	  		priz)
	-- Создаем временную таблицу, именованный подзапрос, с помощью конструкции with as
	-- В этой таблице происходят основные расчеты
	with cte as
		(select 
		    1481 as regn,
		 	-- здесь мы получаем столбец PLAN(chapter) A
			s.chapter									as chapter,
		 	-- Здесь мы получаем номер счета(второго порядка) NUM_CS путем извлечения первых 5 символов
			substr(acc_d.account_number, 1, 5)			as ledger_account,
		 	-- Здесь получаем признак счета активный или пассивный(А или Р) A_P
			acc_d.char_type								as characteristic,
			-- Здесь рассчитывается баланс в рублях по коду валюты VR
			(sum(case 
					when cur.currency_code in ('643', '810')
					then b.balance_out
					else 0
				end) / 1000)									as balance_in_rub,	     
			-- Здесь рассчитывается баланс в валюте и конвертируется в рубли VV
			(sum(case 
					when cur.currency_code not in ('643', '810')
					then ((b.balance_out * exch_r.reduced_cource) / 1000)
					else 0
				end) / 1000)									as balance_in_curr,	       
			-- Total: RUB balance + VAL converted to rub
			(sum(case 
					when cur.currency_code in ('643', '810')
					then b.balance_out
					else b.balance_out * exch_r.reduced_cource
				end) / 1000)									as balance_in_total,	      
			-- Здесь рассчитываются обороты дебета в рублях, сумма значений debet_amount_thousands
			sum(case 
					when cur.currency_code in ('643', '810')
					then coalesce(at.debet_amount_thousands, 0)
					else 0
				end)                              		as turn_deb_rub,	   
			-- Здесь рассчитываются обороты дебета в валюте, сумма значений debet_amount_thousands
			sum(case 
					when cur.currency_code not in ('643', '810')
					then coalesce(at.debet_amount_thousands, 0)
					else 0
				end)                              		as turn_deb_curr,	       
			-- SUM = RUB debet turnover + VAL debet turnover converted
			sum(coalesce(at.debet_amount_thousands, 0))		as turn_deb_total,
			-- Здесь рассчитываются обороты кредета в рублях, сумма значений credit_amount_thousands
			sum(case 
					when cur.currency_code in ('643', '810')
					then coalesce(at.credit_amount_thousands, 0)
					else 0
				end)									as turn_cre_rub,	          
			-- Здесь рассчитываются обороты кредета в валюте, сумма значений credit_amount_thousands
			sum(case 
					when cur.currency_code not in ('643', '810')
					then coalesce(at.credit_amount_thousands, 0)
					else 0
				end)                               		as turn_cre_curr,
			-- SUM = RUB credit turnover + VAL credit turnover converted
			sum(coalesce(at.credit_amount_thousands, 0)) 		as turn_cre_total,	
		 	-- здесь мы получаем месяц за который будет сформирован отчет
		 	-- первый день месяца
			date_trunc('month', i_OnDate)				as from_date,
		 	-- последний день месяца
			date_trunc('MONTH', i_OnDate) + INTERVAL '1 MONTH - 1 day'  as to_date,
		 	1 AS priz
		-- Здесь происходят джоины всех таблиц что бы получить все необходимые данные
		-- Таблицы объединяются по датам, счетам и валюте
		from ds.md_ledger_account_s s
		join ds.md_account_d acc_d
		on substr(acc_d.account_number, 1, 5) = to_char(s.ledger_account, 'FM99999999')
		join ds.md_currency_d cur
		on cur.currency_rk = acc_d.currency_rk
		left 
		join ds.ft_balance_f b
		on b.account_rk = acc_d.account_rk
		and b.on_date  = (date_trunc('month', i_OnDate) - INTERVAL '1 day')
		left 
		join ds.md_exchange_rate_d exch_r
		on exch_r.currency_rk = acc_d.currency_rk
		and i_OnDate between exch_r.data_actual_date 
		and exch_r.data_actual_end_date
		left join dm.dm_account_turnover_f at
		on at.account_rk = acc_d.account_rk
		and at.on_date between date_trunc('month', i_OnDate) and (date_trunc('MONTH', i_OnDate) + INTERVAL '1 MONTH - 1 day')
		where i_OnDate between s.start_date and s.end_date
		and i_OnDate between acc_d.data_actual_date and acc_d.data_actual_end_date
		and i_OnDate between cur.data_actual_date and cur.data_actual_end_date
		group by s.chapter,substr(acc_d.account_number, 1, 5), acc_d.char_type)
		-- здесь заканчивается временная таблица и теперь мы можем выбрать из нее данные для вставки в dm.dm_f101_round_f
		-- Выбираем данные
	select
		regn,         
		chapter,           
		ledger_account,    
		characteristic,    
		balance_in_rub,    
		balance_in_curr,    
		balance_in_total,  
		turn_deb_rub,      
		turn_deb_curr,      
		turn_deb_total,    
		turn_cre_rub,      
		turn_cre_curr,      
		turn_cre_total, 
		-- здесь мы начинаем рассчитывать столбцы Итого исходя из формулы из задания
		((case 
			--BALANCE_OUT_RUB = BALANCE_IN_RUB - TURN_CRE_RUB + TURN_DEB_RUB;
			when characteristic = 'A' 
			then balance_in_rub - turn_cre_rub + turn_deb_rub
			--BALANCE_OUT_RUB = BALANCE_IN_RUB + TURN_CRE_RUB - TURN_DEB_RUB;
			when characteristic = 'P' 
			then balance_in_rub + turn_cre_rub - turn_deb_rub		
		end) / 1000)											as balance_out_rub, 											
		((case 
			when characteristic = 'A' 
			then  balance_in_curr - turn_cre_curr + turn_deb_curr
			--BALANCE_OUT_CURR = BALANCE_IN_CURR + TURN_CRE_CURR - TURN_DEB_CURR;
			when characteristic = 'P' 
			then balance_in_curr + turn_cre_curr - turn_deb_curr  
		end) / 1000) 											as balance_out_curr,
			--BALANCE_OUT_TOTAL = BALANCE_OUT_CURR + BALANCE_OUT_RUB
		((case 				
			when characteristic = 'A' 
			then balance_in_rub - turn_cre_rub + turn_deb_rub			
			when characteristic = 'P' 
			then balance_in_rub + turn_cre_rub - turn_deb_rub		
		 end)
		+
		(case 			
			when characteristic = 'A' 
			then  balance_in_curr - turn_cre_curr + turn_deb_curr
			when characteristic = 'P' 
			then balance_in_curr + turn_cre_curr - turn_deb_curr  
		end) / 1000)											as balance_out_total,
		from_date,         
		to_date,  
		priz
	from cte;
   
commit;    
end;$$	