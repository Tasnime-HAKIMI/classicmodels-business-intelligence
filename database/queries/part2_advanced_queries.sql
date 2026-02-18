USE classicmodels;
/* =========================================================
   NETTOYAGE – DROP (OBLIGATOIRE POUR CTRL+A)
   ========================================================= */

-- Procédures
DROP PROCEDURE IF EXISTS calculate_employee_commission;
DROP PROCEDURE IF EXISTS update_stock;

-- Fonction
DROP FUNCTION IF EXISTS customer_lifetime_value;

-- Triggers
DROP TRIGGER IF EXISTS audit_orders;
DROP TRIGGER IF EXISTS validate_stock;
DROP TRIGGER IF EXISTS update_customer_status;

-- 1. ANALYSE DES VENTES AVEC WINDOW FUNCTIONS
-- Cette requête calcule le rang, la moyenne mobile et le % de contribution par gamme
SELECT 
    c.customerNumber, 
    c.customerName, 
    SUM(od.quantityOrdered * od.priceEach) AS total_sales,

    -- A. RANG : Classement des clients par chiffre d'affaires (décroissant)
    RANK() OVER (
        ORDER BY SUM(od.quantityOrdered * od.priceEach) DESC
    ) AS sales_rank,

    -- B. POURCENTAGE : Contribution du client au CA total de l'entreprise
    ROUND(
        100 * SUM(od.quantityOrdered * od.priceEach) 
        / SUM(SUM(od.quantityOrdered * od.priceEach)) OVER (), 
        2
    ) AS pct_of_total_sales,

    -- C. MOYENNE MOBILE : Moyenne du CA sur 3 clients (précédent, actuel, suivant)
    -- On utilise DESC pour rester cohérent avec le classement des ventes
    ROUND(
        AVG(SUM(od.quantityOrdered * od.priceEach)) OVER (
            ORDER BY SUM(od.quantityOrdered * od.priceEach) DESC
            ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
        ), 
        2
    ) AS moving_avg_sales

FROM customers c
JOIN orders o ON c.customerNumber = o.customerNumber
JOIN orderdetails od ON o.orderNumber = od.orderNumber
GROUP BY c.customerNumber, c.customerName
ORDER BY total_sales DESC;

-- (2) Hiérarchie organisationnelle avec CTE RÉCURSIF
-- Cette requête reconstruit l'organigramme de l'entreprise niveau par niveau
-- Cette version se concentre sur les niveaux hiérarchiques (Level)
WITH RECURSIVE EmployeeHierarchy AS (
    -- Cas de base : Le sommet de la pyramide (le Président)
    SELECT 
        employeeNumber, 
        firstName, 
        lastName, 
        jobTitle,
        reportsTo, 
        1 AS level -- On commence au niveau 1
    FROM employees
    WHERE reportsTo IS NULL
    
    UNION ALL
    
    -- Cas récursif : On ajoute les subordonnés en incrémentant le niveau
    SELECT 
        e.employeeNumber, 
        e.firstName, 
        e.lastName, 
        e.jobTitle,
        e.reportsTo, 
        eh.level + 1 -- On descend d'un cran dans l'organigramme
    FROM employees e
    INNER JOIN EmployeeHierarchy eh ON e.reportsTo = eh.employeeNumber
)
-- Affichage final trié par niveau hiérarchique
SELECT 
    level,
    employeeNumber,
    CONCAT(firstName, ' ', lastName) AS employee_name,
    jobTitle,
    reportsTo AS manager_id
FROM EmployeeHierarchy
ORDER BY level, lastName;

-- (3) Segmentation clients VIP avec JOINTURES MULTIPLES (5+ tables)
-- Objectif : Identifier les clients ayant généré plus de 100 000 $ de CA, 
-- avec les détails de leur représentant commercial et de leur bureau.
SELECT 
    c.customerName,
    c.city AS customer_city,
    CONCAT(e.firstName, ' ', e.lastName) AS sales_rep_name,
    off.city AS office_city,
    COUNT(DISTINCT o.orderNumber) AS total_orders,
    SUM(od.quantityOrdered * od.priceEach) AS total_spent,
    -- Label de segmentation pour le rapport
    CASE 
        WHEN SUM(od.quantityOrdered * od.priceEach) > 200000 THEN 'Platinum VIP'
        ELSE 'Gold VIP'
    END AS vip_status
FROM customers c
JOIN employees e ON c.salesRepEmployeeNumber = e.employeeNumber    -- Table 2
JOIN offices off ON e.officeCode = off.officeCode                -- Table 3
JOIN orders o ON c.customerNumber = o.customerNumber              -- Table 4
JOIN orderdetails od ON o.orderNumber = od.orderNumber            -- Table 5
JOIN products p ON od.productCode = p.productCode                 -- Table 6 (Optionnelle ici mais utile pour filtrer par gamme)
GROUP BY 
    c.customerNumber, 
    c.customerName, 
    c.city, 
    e.firstName, 
    e.lastName, 
    off.city
HAVING total_spent > 100000
ORDER BY total_spent DESC;


-- (4) Analyse temporelle avec SOUS-REQUÊTES CORRÉLÉES
-- Objectif : Déterminer si chaque commande provient d'un nouveau client ou d'un client fidèle, mais ici c'est jour par jour , c'est enorme
SELECT 
    o1.orderNumber,
    o1.orderDate,
    c.customerName,
    -- Sous-requête corrélée : Compte les commandes antérieures pour le même client
    (SELECT COUNT(*) 
     FROM orders o2 
     WHERE o2.customerNumber = o1.customerNumber 
     AND o2.orderDate < o1.orderDate) AS nb_commandes_precedentes,

    -- Logique de segmentation de la rétention
    CASE 
        WHEN (
            SELECT COUNT(*) 
            FROM orders o2 
            WHERE o2.customerNumber = o1.customerNumber 
            AND o2.orderDate < o1.orderDate
        ) = 0 THEN 'Nouveau Client'
        ELSE 'Fidélisation (Rétention)'
    END AS type_client

FROM orders o1
JOIN customers c ON o1.customerNumber = c.customerNumber
ORDER BY o1.orderDate ASC;


-- (4) Analyse temporelle : Nouveaux clients vs Rétention Annuelle
-- Cette requête calcule par mois le nombre de nouveaux clients
-- et combien parmi eux étaient déjà présents l'année précédente (N-1)
SELECT
    YEAR(o.orderDate) AS year,

    -- Nouveaux clients (première commande cette année)
    COUNT(DISTINCT
        CASE
            WHEN YEAR(o.orderDate) =
                 (
                     SELECT MIN(YEAR(o2.orderDate))
                     FROM orders o2
                     WHERE o2.customerNumber = o.customerNumber
                 )
            THEN o.customerNumber
        END
    ) AS new_customers,

    -- Clients retenus (commandes année N ET N-1)
    COUNT(DISTINCT
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM orders o_prev
                WHERE o_prev.customerNumber = o.customerNumber
                  AND YEAR(o_prev.orderDate) = YEAR(o.orderDate) - 1
            )
            THEN o.customerNumber
        END
    ) AS retained_customers

FROM orders o
GROUP BY YEAR(o.orderDate)
ORDER BY year;

-- (5) Rapport PIVOT : Performance des ventes par gamme et par trimestre (Année 2004)
-- Ce code combine une structure multi-jointures avec une analyse temporelle précise
SELECT 
    pl.productLine,

    -- Calcul par trimestre pour l'année 2004
    ROUND(SUM(CASE WHEN QUARTER(o.orderDate) = 1 THEN od.quantityOrdered * od.priceEach ELSE 0 END), 2) AS Q1_2004,
    ROUND(SUM(CASE WHEN QUARTER(o.orderDate) = 2 THEN od.quantityOrdered * od.priceEach ELSE 0 END), 2) AS Q2_2004,
    ROUND(SUM(CASE WHEN QUARTER(o.orderDate) = 3 THEN od.quantityOrdered * od.priceEach ELSE 0 END), 2) AS Q3_2004,
    ROUND(SUM(CASE WHEN QUARTER(o.orderDate) = 4 THEN od.quantityOrdered * od.priceEach ELSE 0 END), 2) AS Q4_2004,

    -- Colonne de vérification : Total annuel par gamme
    ROUND(SUM(od.quantityOrdered * od.priceEach), 2) AS Total_Annuel_2004

FROM productlines pl
JOIN products p ON pl.productLine = p.productLine
JOIN orderdetails od ON p.productCode = od.productCode
JOIN orders o ON od.orderNumber = o.orderNumber
-- On filtre sur une année précise pour que le pivot trimestriel ait du sens
WHERE YEAR(o.orderDate) = 2004 
GROUP BY pl.productLine
-- On trie par le plus gros chiffre d'affaires pour mettre en avant les succès
ORDER BY Total_Annuel_2004 DESC;

SELECT
    pl.productLine,

    SUM(CASE WHEN QUARTER(o.orderDate) = 1 
             THEN od.quantityOrdered * od.priceEach ELSE 0 END) AS Q1,

    SUM(CASE WHEN QUARTER(o.orderDate) = 2 
             THEN od.quantityOrdered * od.priceEach ELSE 0 END) AS Q2,

    SUM(CASE WHEN QUARTER(o.orderDate) = 3 
             THEN od.quantityOrdered * od.priceEach ELSE 0 END) AS Q3,

    SUM(CASE WHEN QUARTER(o.orderDate) = 4 
             THEN od.quantityOrdered * od.priceEach ELSE 0 END) AS Q4

FROM productlines pl
JOIN products p 
    ON pl.productLine = p.productLine
JOIN orderdetails od 
    ON p.productCode = od.productCode
JOIN orders o 
    ON od.orderNumber = o.orderNumber
WHERE YEAR(o.orderDate) IS NOT NULL
GROUP BY pl.productLine
ORDER BY pl.productLine;

-- ==========================================================
-- PARTIE 2 : PROGRAMMATION SQL (Procédures, Fonctions, Triggers)
-- ==========================================================

-- 1. PROCÉDURES STOCKÉES
-- ----------------------------------------------------------

-- A. Calcul de la commission d'un employé (5% des ventes)
DELIMITER //
CREATE PROCEDURE sp_calcul_commission(IN p_empNumber INT)
BEGIN
    SELECT 
        e.employeeNumber, 
        e.lastName, 
        SUM(od.quantityOrdered * od.priceEach) AS chiffre_affaires,
        SUM(od.quantityOrdered * od.priceEach) * 0.05 AS commission_montant
    FROM employees e
    JOIN customers c ON e.employeeNumber = c.salesRepEmployeeNumber
    JOIN orders o ON c.customerNumber = o.customerNumber
    JOIN orderdetails od ON o.orderNumber = od.orderNumber
    WHERE e.employeeNumber = p_empNumber
    GROUP BY e.employeeNumber;
END //

-- B. Gestion des stocks (Mise à jour manuelle du stock)
CREATE PROCEDURE sp_gestion_stock(IN p_productCode VARCHAR(15), IN p_quantite INT)
BEGIN
    UPDATE products 
    SET quantityInStock = quantityInStock + p_quantite 
    WHERE productCode = p_productCode;
END //
DELIMITER ;

-- 2. FONCTION
-- ----------------------------------------------------------

-- Customer Lifetime Value (Somme totale des paiements d'un client)
DELIMITER //
CREATE FUNCTION fn_customer_clv(p_custNumber INT) 
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    DECLARE v_clv DECIMAL(10,2);
    SELECT SUM(amount) INTO v_clv FROM payments WHERE customerNumber = p_custNumber;
    RETURN IFNULL(v_clv, 0);
END //
DELIMITER ;

-- 3. TRIGGERS (DÉCLENCHEURS)
-- ----------------------------------------------------------

-- Table technique pour l'Audit (à créer avant le trigger)
CREATE TABLE IF NOT EXISTS orders_audit (
    audit_id INT AUTO_INCREMENT PRIMARY KEY,
    orderNumber INT,
    old_status VARCHAR(20),
    new_status VARCHAR(20),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

DELIMITER //

-- A. Trigger Audit Orders : Trace les changements de statut
CREATE TRIGGER trg_audit_status_update
AFTER UPDATE ON orders
FOR EACH ROW
BEGIN
    IF OLD.status <> NEW.status THEN
        INSERT INTO orders_audit (orderNumber, old_status, new_status)
        VALUES (OLD.orderNumber, OLD.status, NEW.status);
    END IF;
END //

-- B. Trigger Validation Stock : Empêche de commander plus que le stock disponible
CREATE TRIGGER trg_check_stock_before_order
BEFORE INSERT ON orderdetails
FOR EACH ROW
BEGIN
    DECLARE v_stock INT;
    SELECT quantityInStock INTO v_stock FROM products WHERE productCode = NEW.productCode;
    IF NEW.quantityOrdered > v_stock THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Action annulée : Stock insuffisant pour ce produit !';
    END IF;
END //

-- C. Trigger Statut Client : Ajoute la mention (VIP) si le client dépasse 100 000 de paiements
CREATE TRIGGER trg_update_vip_status
AFTER INSERT ON payments
FOR EACH ROW
BEGIN
    DECLARE v_total_paid DECIMAL(10,2);
    SELECT SUM(amount) INTO v_total_paid FROM payments WHERE customerNumber = NEW.customerNumber;
    
    IF v_total_paid > 100000 THEN
        UPDATE customers 
        SET contactLastName = CONCAT(contactLastName, ' (VIP)')
        WHERE customerNumber = NEW.customerNumber 
        AND contactLastName NOT LIKE '%(VIP)%';
    END IF;
END //

DELIMITER ;


