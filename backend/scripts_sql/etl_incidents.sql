CREATE PROC PROC_ETL_INCIDENTES_SERVICE_NOW
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Variável para controle de atualização incremental
    -- DECLARE @data_corte DATETIME = DATEADD(DAY, -10, GETDATE())
    
    -- Inserir ou atualizar Assignment Groups
    INSERT INTO dw_analytics.d_assignment_group (id, dv_assignment_group)
    SELECT id, dv_assignment_group
    FROM (
        SELECT 
            LTRIM(RTRIM(assignment_group)) AS id,
            LTRIM(RTRIM(dv_assignment_group)) AS dv_assignment_group,
            ROW_NUMBER() OVER (PARTITION BY LTRIM(RTRIM(assignment_group)) ORDER BY (SELECT NULL)) AS rn
        FROM SERVICE_NOW.dbo.incident
        WHERE LTRIM(RTRIM(assignment_group)) != ''
          AND LTRIM(RTRIM(dv_assignment_group)) != ''
    ) AS SubQuery
    WHERE rn = 1;

    -- Inserir ou atualizar Resolved By
    INSERT INTO dw_analytics.d_resolved_by (id, dv_resolved_by)
    SELECT id, dv_resolved_by
    FROM (
        SELECT 
            LTRIM(RTRIM(resolved_by)) AS id,
            LTRIM(RTRIM(dv_resolved_by)) AS dv_resolved_by,
            ROW_NUMBER() OVER (PARTITION BY LTRIM(RTRIM(resolved_by)) ORDER BY (SELECT NULL)) AS rn
        FROM SERVICE_NOW.dbo.incident
        WHERE LTRIM(RTRIM(resolved_by)) != ''
          AND LTRIM(RTRIM(dv_resolved_by)) != ''
    ) AS SubQuery
    WHERE rn = 1;

    -- Inserir ou atualizar Contract
    INSERT INTO dw_analytics.d_contract (id, dv_contract)
    SELECT id, dv_contract
    FROM (
        SELECT 
            LTRIM(RTRIM(contract)) AS id,
            LTRIM(RTRIM(dv_contract)) AS dv_contract,
            ROW_NUMBER() OVER (PARTITION BY LTRIM(RTRIM(contract)) ORDER BY (SELECT NULL)) AS rn
        FROM SERVICE_NOW.dbo.incident
        WHERE LTRIM(RTRIM(contract)) != ''
          AND LTRIM(RTRIM(dv_contract)) != ''
    ) AS SubQuery
    WHERE rn = 1;

    -- Inserir ou atualizar Company
    INSERT INTO dw_analytics.d_company (id, dv_company, u_cnpj)
    SELECT id, dv_company, u_cnpj
    FROM (
        SELECT 
            LTRIM(RTRIM(company)) AS id,
            LTRIM(RTRIM(dv_company)) AS dv_company,
            LTRIM(RTRIM(u_cnpj)) AS u_cnpj,
            ROW_NUMBER() OVER (PARTITION BY LTRIM(RTRIM(company)) ORDER BY (SELECT NULL)) AS rn
        FROM SERVICE_NOW.dbo.incident
        WHERE LTRIM(RTRIM(company)) != ''
          AND LTRIM(RTRIM(dv_company)) != ''
          AND LTRIM(RTRIM(u_cnpj)) != ''
    ) AS SubQuery
    WHERE rn = 1;

    -- Relacionamento Resolved By - Assignment Group
    INSERT INTO d_resolved_by_assignment_group (id, resolved_by_id, assignment_group_id)
    SELECT NEWID() AS ID, resolved_by_id, assignment_group_id
    FROM (
        SELECT 
            rb.id AS resolved_by_id,
            ag.id AS assignment_group_id,
            ROW_NUMBER() OVER (PARTITION BY rb.id, ag.id ORDER BY (SELECT NULL)) AS rn
        FROM SERVICE_NOW.dbo.incident inc
        JOIN d_resolved_by rb ON rb.dv_resolved_by = inc.resolved_by
        JOIN d_assignment_group ag ON ag.dv_assignment_group = inc.assignment_group
        WHERE inc.resolved_by IS NOT NULL
        AND inc.assignment_group IS NOT NULL
        AND inc.resolved_by NOT IN ('')
        AND inc.assignment_group NOT IN ('')
    ) AS SubQuery
    WHERE rn = 1;

    -- Inserir ou atualizar Incidents na tabela fato
    MERGE f_incident AS target
    USING (
        SELECT 
            inc.number as id,
            inc.resolved_by as resolved_by_id,
            inc.assignment_group as assignment_group_id,
            inc.opened_at,
            inc.closed_at,
            inc.contract as contract_id,
            inc.sla_atendimento,
            inc.sla_resolucao,
            inc.company,
            inc.u_origem,
            inc.dv_u_categoria_falha,
            inc.dv_u_sub_categoria_da_falha,
            inc.dv_u_detalhe_sub_categoria_da_falha
        FROM SERVICE_NOW.dbo.incident inc
        WHERE inc.number IS NOT NULL
    ) AS source
    ON target.id = source.id
    WHEN MATCHED THEN
        UPDATE SET
            resolved_by_id = source.resolved_by_id,
            assignment_group_id = source.assignment_group_id,
            opened_at = source.opened_at,
            closed_at = source.closed_at,
            contract_id = source.contract_id,
            sla_atendimento = source.sla_atendimento,
            sla_resolucao = source.sla_resolucao,
            company = source.company,
            u_origem = source.u_origem,
            dv_u_categoria_falha = source.dv_u_categoria_falha,
            dv_u_sub_categoria_da_falha = source.dv_u_sub_categoria_da_falha,
            dv_u_detalhe_sub_categoria_da_falha = source.dv_u_detalhe_sub_categoria_da_falha
    WHEN NOT MATCHED THEN
        INSERT (
            id, resolved_by_id, assignment_group_id, opened_at, closed_at,
            contract_id, sla_atendimento, sla_resolucao, company,
            u_origem, dv_u_categoria_falha, dv_u_sub_categoria_da_falha,
            dv_u_detalhe_sub_categoria_da_falha
        )
        VALUES (
            source.id, source.resolved_by_id, source.assignment_group_id,
            source.opened_at, source.closed_at, source.contract_id,
            source.sla_atendimento, source.sla_resolucao, source.company,
            source.u_origem, source.dv_u_categoria_falha,
            source.dv_u_sub_categoria_da_falha,
            source.dv_u_detalhe_sub_categoria_da_falha
        );

    -- Atualizar Sorted Tickets para chamados fechados
    INSERT INTO d_sorted_ticket (incident_id, mes_ano)
    SELECT 
        i.id,
        FORMAT(i.closed_at, 'yyyy-MM') as mes_ano
    FROM f_incident i
    LEFT JOIN d_sorted_ticket st ON 
        st.incident_id = i.id AND 
        st.mes_ano = FORMAT(i.closed_at, 'yyyy-MM')
    WHERE 
        i.closed_at IS NOT NULL AND
        st.id IS NULL;

END;

-- Comentário explicativo sobre a atualização incremental
/*
NOTAS SOBRE ATUALIZAÇÃO INCREMENTAL:

1. Na primeira execução, rodar sem os filtros para carregar todo o histórico
2. Nas execuções subsequentes, descomentar os filtros para processamento incremental
3. O período de 10 dias pode ser ajustado conforme necessidade
4. Considerar adicionar índices em opened_at, closed_at e sys_updated_on na tabela fonte
5. Monitorar performance e ajustar conforme necessário
*/
