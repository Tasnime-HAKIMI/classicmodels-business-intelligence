USE classicmodels;
-- =========================
-- 1. Exploration de la base
-- =========================

-- Afficher toutes les tables de la base
SHOW TABLES;

-- Afficher les 10 premiers clients pour comprendre la structure des données
SELECT * FROM customers LIMIT 10;

-- Décrire la structure de chaque table principale
DESCRIBE customers;
DESCRIBE orders;
DESCRIBE products;
DESCRIBE orderdetails;

-- Q1 Compter le nombre d’éléments dans chaque table principale
-- Utilisation de UNION ALL pour afficher les résultats dans une seule table
SELECT 'Clients' AS element, COUNT(*) AS total FROM customers
UNION ALL
SELECT 'Employés', COUNT(*) FROM employees
UNION ALL
SELECT 'Bureaux', COUNT(*) FROM offices
UNION ALL
SELECT 'Commandes', COUNT(*) FROM orders
UNION ALL
SELECT 'Produits', COUNT(*) FROM products
UNION ALL
SELECT 'Gammes de produits', COUNT(*) FROM productlines;

-- =========================
-- Q2. Analyse des clients
-- =========================

-- Compter le nombre total de clients
SELECT COUNT(*) AS total_customers 
FROM customers;

-- Nombre de clients par pays
-- Permet d’identifier les pays où l’entreprise est la plus présente
SELECT country, COUNT(*) AS nb_clients
FROM customers
GROUP BY country
ORDER BY nb_clients DESC;

-- Q3: Commandes par statut
SELECT status, COUNT(*) AS total 
FROM orders 
GROUP BY status 
ORDER BY total DESC;


-- =========================
-- Q4 Indicateurs de performance
-- =========================

-- Calcul du chiffre d’affaires total et du panier moyen
-- Seulement pour les commandes expédiées
SELECT 
  SUM(od.quantityOrdered * od.priceEach) AS Total_des_ventes,
  SUM(od.quantityOrdered * od.priceEach) / COUNT(DISTINCT o.orderNumber) AS Panier_moyen
FROM orders o
JOIN orderdetails od 
  ON od.orderNumber = o.orderNumber
WHERE o.status = 'Shipped';



-- Q5 Top 10 des produits les plus vendus (en quantité)
SELECT 
  p.productName AS Produit,
  SUM(od.quantityOrdered) AS Quantite_totale_vendue
FROM orderdetails od
JOIN products p 
  ON p.productCode = od.productCode
JOIN orders o 
  ON o.orderNumber = od.orderNumber
WHERE o.status = 'Shipped'
GROUP BY p.productName
ORDER BY Quantite_totale_vendue DESC
LIMIT 10;

-- Q6 Top 5 des clients générant le plus de chiffre d’affaires
SELECT 
  c.customerName AS Client,
  SUM(od.quantityOrdered * od.priceEach) AS Chiffre_affaires
FROM customers c
JOIN orders o 
  ON o.customerNumber = c.customerNumber
JOIN orderdetails od 
  ON od.orderNumber = o.orderNumber
WHERE o.status = 'Shipped'
GROUP BY c.customerName
ORDER BY Chiffre_affaires DESC
LIMIT 5;


-- =========================
-- Q7 Meilleur commercial
-- =========================

-- Employé ayant généré le plus de chiffre d’affaires
SELECT 
  CONCAT(e.firstName, ' ', e.lastName) AS Employe,
  SUM(od.quantityOrdered * od.priceEach) AS Chiffre_affaires
FROM employees e
JOIN customers c 
  ON c.salesRepEmployeeNumber = e.employeeNumber
JOIN orders o 
  ON o.customerNumber = c.customerNumber
JOIN orderdetails od 
  ON od.orderNumber = o.orderNumber
WHERE o.status = 'Shipped'
GROUP BY Employe
ORDER BY Chiffre_affaires DESC
LIMIT 1;


-- =========================
-- Q8 Performance par gamme
-- =========================

-- Chiffre d’affaires par gamme de produits
SELECT 
  p.productLine AS Gamme_de_produits,
  SUM(od.quantityOrdered * od.priceEach) AS Chiffre_affaires
FROM products p
JOIN orderdetails od 
  ON od.productCode = p.productCode
JOIN orders o 
  ON o.orderNumber = od.orderNumber
WHERE o.status = 'Shipped'
GROUP BY p.productLine
ORDER BY Chiffre_affaires DESC;




