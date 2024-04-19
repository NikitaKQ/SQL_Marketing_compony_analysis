WITH CompanyUsers AS (
    SELECT id AS company_id, name
    FROM users
    WHERE owner_id IS NULL OR owner_id NOT IN (SELECT id FROM users)
),
EarliestCampaigns AS (
    SELECT
        pd.user_id,
        pd.rk_id,
        RANK() OVER (PARTITION BY pd.user_id ORDER BY ac.create_date ASC, pd.rk_id DESC) AS rk_rank
    FROM payment_date pd
    JOIN advertising_companies ac ON pd.rk_id = ac.id
    WHERE pd.sum > 0
),
MainCampaigns AS (
    SELECT
        pd.user_id,
        pd.rk_id
    FROM payment_date pd
    JOIN advertising_companies ac ON pd.rk_id = ac.id
    WHERE ac.is_main = 1 AND pd.sum > 0
),
CombinedCampaigns AS (
    SELECT user_id, rk_id FROM EarliestCampaigns WHERE rk_rank = 1
    UNION
    SELECT user_id, rk_id FROM MainCampaigns
),
ValidPayments AS (
    SELECT
        cc.user_id,
        SUM(pd.sum) AS total_sum
    FROM CombinedCampaigns cc
    JOIN payment_date pd ON cc.user_id = pd.user_id AND cc.rk_id = pd.rk_id
    WHERE pd.sum > 0
    GROUP BY cc.user_id
),
TotalPayments AS (
    SELECT
        (CASE WHEN u.owner_id IS NULL OR u.owner_id NOT IN (SELECT id FROM users) THEN u.id ELSE u.owner_id END) AS main_company_id,
        SUM(vp.total_sum) AS total_sum
    FROM users u
    JOIN ValidPayments vp ON u.id = vp.user_id
    GROUP BY main_company_id
)
SELECT
    cu.name,
    tp.total_sum AS budget
FROM CompanyUsers cu
LEFT JOIN TotalPayments tp ON cu.company_id = tp.main_company_id
ORDER BY cu.name;

