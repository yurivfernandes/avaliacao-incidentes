CREATE PROC PROC_ETL_INCIDENTES_SERVICE_NOW
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Variável para controle de atualização incremental
    -- DECLARE @data_corte DATETIME = DATEADD(DAY, -10, GETDATE())
    
    -- Inserir novos Assignment Groups
    INSERT INTO dw_analytics.d_assignment_group (id, dv_assignment_group)
    SELECT DISTINCT 
        LTRIM(RTRIM(inc.assignment_group)) AS id,
        LTRIM(RTRIM(inc.dv_assignment_group)) AS dv_assignment_group
    FROM SERVICE_NOW.dbo.incident inc
    LEFT JOIN dw_analytics.d_assignment_group ag 
        ON LTRIM(RTRIM(inc.assignment_group)) = ag.id
    WHERE ag.id IS NULL
        AND inc.assignment_group IS NOT NULL
        AND inc.assignment_group != ''
        AND inc.dv_assignment_group != '';

    -- Inserir novos Resolved By
    INSERT INTO dw_analytics.d_resolved_by (id, dv_resolved_by)
    SELECT DISTINCT
        LTRIM(RTRIM(inc.resolved_by)) AS id,
        LTRIM(RTRIM(inc.dv_resolved_by)) AS dv_resolved_by
    FROM SERVICE_NOW.dbo.incident inc
    LEFT JOIN dw_analytics.d_resolved_by rb 
        ON LTRIM(RTRIM(inc.resolved_by)) = rb.id
    WHERE rb.id IS NULL
        AND inc.resolved_by IS NOT NULL
        AND inc.resolved_by != ''
        AND inc.dv_resolved_by != '';

    -- Inserir novos Contracts
    INSERT INTO dw_analytics.d_contract (id, dv_contract)
    SELECT DISTINCT
        LTRIM(RTRIM(inc.contract)) AS id,
        LTRIM(RTRIM(inc.dv_contract)) AS dv_contract
    FROM SERVICE_NOW.dbo.incident inc
    LEFT JOIN dw_analytics.d_contract c 
        ON LTRIM(RTRIM(inc.contract)) = c.id
    WHERE c.id IS NULL
        AND inc.contract IS NOT NULL
        AND inc.contract != ''
        AND inc.dv_contract != '';

    -- Inserir novas Companies
    INSERT INTO dw_analytics.d_company (id, dv_company, u_cnpj)
    SELECT DISTINCT
        LTRIM(RTRIM(inc.company)) AS id,
        LTRIM(RTRIM(inc.dv_company)) AS dv_company,
        REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(inc.u_cnpj)), '.', ''), '/', ''), '-', '') AS u_cnpj
    FROM SERVICE_NOW.dbo.incident inc
    LEFT JOIN dw_analytics.d_company c 
        ON LTRIM(RTRIM(inc.company)) = c.id
    WHERE c.id IS NULL
        AND inc.company IS NOT NULL
        AND inc.company != ''
        AND inc.dv_company != ''
        AND inc.u_cnpj != '';

    -- Relacionamento Resolved By - Assignment Group
    INSERT INTO dw_analytics.d_resolved_by_assignment_group (resolved_by_id, assignment_group_id)
    SELECT resolved_by_id, assignment_group_id
    FROM (
        SELECT 
            LTRIM(RTRIM(inc.resolved_by)) AS resolved_by_id,
            LTRIM(RTRIM(inc.assignment_group)) AS assignment_group_id,
            ROW_NUMBER() OVER (PARTITION BY LTRIM(RTRIM(inc.resolved_by)), LTRIM(RTRIM(inc.assignment_group)) ORDER BY (SELECT NULL)) AS rn
        FROM SERVICE_NOW.dbo.incident inc
        INNER JOIN dw_analytics.d_resolved_by rb 
            ON LTRIM(RTRIM(inc.resolved_by)) = rb.id
        INNER JOIN dw_analytics.d_assignment_group ag 
            ON LTRIM(RTRIM(inc.assignment_group)) = ag.id
        WHERE inc.resolved_by IS NOT NULL
        AND inc.assignment_group IS NOT NULL
        AND inc.resolved_by != ''
        AND inc.assignment_group != ''
    ) AS SubQuery
    WHERE rn = 1;

    -- Inserir ou atualizar Incidents na tabela fato
    MERGE dw_analytics.f_incident AS target
    USING (
        SELECT 
            number, resolved_by, assignment_group, opened_at, closed_at,
            contract, sla_atendimento, sla_resolucao, company,
            u_origem, dv_u_categoria_da_falha, dv_u_sub_categoria_da_falha,
            dv_u_detalhe_sub_categoria_da_falha
        FROM (
            SELECT 
                inc.number,
                inc.resolved_by,
                inc.assignment_group,
                inc.opened_at,
                inc.closed_at,
                inc.contract,
                sla_first.has_breached as sla_atendimento,
                sla_resolved.has_breached as sla_resolucao,
                inc.company,
                inc.u_origem,
                inc.dv_u_categoria_da_falha,
                inc.dv_u_sub_categoria_da_falha,
                inc.dv_u_detalhe_sub_categoria_da_falha,
                ROW_NUMBER() OVER (
                    PARTITION BY inc.number 
                    ORDER BY 
                        CASE 
                            WHEN inc.dv_state IN ('Encerrado', 'Closed') THEN 0
                            ELSE 1
                        END,
                        inc.sys_id
                ) as rn
            FROM SERVICE_NOW.dbo.incident inc
            LEFT JOIN SERVICE_NOW.dbo.incident_sla sla_first 
                ON inc.sys_id = sla_first.task 
                AND sla_first.dv_sla LIKE '%VITA] FIRST%'
            LEFT JOIN SERVICE_NOW.dbo.incident_sla sla_resolved 
                ON inc.sys_id = sla_resolved.task 
                AND sla_resolved.dv_sla LIKE '%VITA] RESOLVED%'
            WHERE inc.number IS NOT NULL
        ) AS DedupedIncidents
        WHERE rn = 1
    ) AS source
    ON target.number = source.number
    WHEN MATCHED THEN
        UPDATE SET
            resolved_by = source.resolved_by,
            assignment_group = source.assignment_group,
            opened_at = source.opened_at,
            closed_at = source.closed_at,
            contract = source.contract,
            sla_atendimento = source.sla_atendimento,
            sla_resolucao = source.sla_resolucao,
            company = source.company,
            u_origem = source.u_origem,
            dv_u_categoria_da_falha = source.dv_u_categoria_da_falha,
            dv_u_sub_categoria_da_falha = source.dv_u_sub_categoria_da_falha,
            dv_u_detalhe_sub_categoria_da_falha = source.dv_u_detalhe_sub_categoria_da_falha
    WHEN NOT MATCHED THEN
        INSERT (
            number, resolved_by, assignment_group, opened_at, closed_at,
            contract, sla_atendimento, sla_resolucao, company,
            u_origem, dv_u_categoria_da_falha, dv_u_sub_categoria_da_falha,
            dv_u_detalhe_sub_categoria_da_falha
        )
        VALUES (
            source.number, source.resolved_by, source.assignment_group,
            source.opened_at, source.closed_at, source.contract,
            source.sla_atendimento, source.sla_resolucao, source.company,
            source.u_origem, source.dv_u_categoria_da_falha,
            source.dv_u_sub_categoria_da_falha,
            source.dv_u_detalhe_sub_categoria_da_falha
        );

    -- Atualizar Sorted Tickets para todos os meses
    WITH IncidentesParaSorteio AS (
        SELECT 
            i.id,
            i.resolved_by,
            FORMAT(i.closed_at, 'yyyy-MM') as mes_ano,
            ROW_NUMBER() OVER (
                PARTITION BY i.resolved_by, FORMAT(i.closed_at, 'yyyy-MM')
                ORDER BY NEWID()
            ) as ordem_sorteio
        FROM dw_analytics.f_incident i
        LEFT JOIN dw_analytics.d_sorted_ticket st 
            ON st.incident_id = i.id 
            AND st.mes_ano = FORMAT(i.closed_at, 'yyyy-MM')
        INNER JOIN SERVICE_NOW.dbo.incident inc 
            ON i.number = inc.number
        WHERE 
            i.closed_at IS NOT NULL AND
            i.resolved_by IS NOT NULL AND
            inc.dv_state IN ('Encerrado', 'Closed') AND
            st.id IS NULL
    )
    INSERT INTO dw_analytics.d_sorted_ticket (incident_id, mes_ano)
    SELECT 
        id,
        mes_ano
    FROM IncidentesParaSorteio
    WHERE ordem_sorteio <= 5;  -- Número de tickets sorteados por analista por mês

    -- Script para atualização mensal (comentado)
    /*
    WITH IncidentesParaSorteio AS (
        SELECT 
            i.id,
            i.resolved_by,
            FORMAT(i.closed_at, 'yyyy-MM') as mes_ano,
            ROW_NUMBER() OVER (
                PARTITION BY i.resolved_by, FORMAT(i.closed_at, 'yyyy-MM')
                ORDER BY NEWID()
            ) as ordem_sorteio
        FROM dw_analytics.f_incident i
        LEFT JOIN dw_analytics.d_sorted_ticket st 
            ON st.incident_id = i.id 
            AND st.mes_ano = FORMAT(i.closed_at, 'yyyy-MM')
        INNER JOIN SERVICE_NOW.dbo.incident inc 
            ON i.number = inc.number
        WHERE 
            i.closed_at IS NOT NULL AND
            i.resolved_by IS NOT NULL AND
            inc.dv_state IN ('Encerrado', 'Closed') AND
            st.id IS NULL AND
            FORMAT(i.closed_at, 'yyyy-MM') = FORMAT(GETDATE(), 'yyyy-MM')
    )
    INSERT INTO dw_analytics.d_sorted_ticket (incident_id, mes_ano)
    SELECT 
        id,
        mes_ano
    FROM IncidentesParaSorteio
    WHERE ordem_sorteio <= 5;  -- Número de tickets sorteados por analista por mês
    */

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

-- Script para verificar duplicações na tabela de incidentes
SELECT 
    number as numero_incidente,
    FORMAT(opened_at, 'yyyy-MM') as mes_ano,
    COUNT(*) as quantidade_duplicacoes
FROM SERVICE_NOW.dbo.incident
WHERE number IS NOT NULL
GROUP BY number, FORMAT(opened_at, 'yyyy-MM')
HAVING COUNT(*) > 1
ORDER BY FORMAT(opened_at, 'yyyy-MM') DESC, COUNT(*) DESC;

-- Procedure para sorteio de tickets por fila
CREATE OR ALTER PROC PROC_SORTEAR_TICKETS_POR_FILA
    @assignment_group NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    -- Atualizar Sorted Tickets para todos os meses
    WITH IncidentesParaSorteio AS (
        SELECT 
            i.id,
            i.resolved_by,
            FORMAT(i.closed_at, 'yyyy-MM') as mes_ano,
            ROW_NUMBER() OVER (
                PARTITION BY i.resolved_by, FORMAT(i.closed_at, 'yyyy-MM')
                ORDER BY NEWID()
            ) as ordem_sorteio
        FROM dw_analytics.f_incident i
        LEFT JOIN dw_analytics.d_sorted_ticket st 
            ON st.incident_id = i.id 
            AND st.mes_ano = FORMAT(i.closed_at, 'yyyy-MM')
        INNER JOIN SERVICE_NOW.dbo.incident inc 
            ON i.number = inc.number
        WHERE 
            i.closed_at IS NOT NULL AND
            i.resolved_by IS NOT NULL AND
            inc.dv_state IN ('Encerrado', 'Closed') AND
            i.assignment_group = @assignment_group AND
            st.id IS NULL
    )
    INSERT INTO dw_analytics.d_sorted_ticket (incident_id, mes_ano)
    SELECT 
        id,
        mes_ano
    FROM IncidentesParaSorteio
    WHERE ordem_sorteio <= 5;  -- Número de tickets sorteados por analista por mês
END;
