# ======================================================
# Importation des bibliothèques nécessaires
# pandas sert à manipuler les tableaux de données
# matplotlib sert à créer les graphiques
# mysql.connector sert à se connecter à MySQL (Workbench)
# ======================================================

import mysql.connector
import pandas as pd
import matplotlib.pyplot as plt

# 1) Connexion à MySQL (la même base que Workbench)
conn = mysql.connector.connect(
    host="localhost",
    user="root",
    password="visiteur",
    database="classicmodels",
    port=3306
)


# ======================================================
# GRAPHIQUE 0 : Volumes des entités principales
# (Q1: clients, employés, bureaux, commandes, produits, gammes)
# ======================================================

query_counts = """
SELECT 'Clients' AS Element, COUNT(*) AS Total FROM customers
UNION ALL SELECT 'Employés', COUNT(*) FROM employees
UNION ALL SELECT 'Bureaux', COUNT(*) FROM offices
UNION ALL SELECT 'Commandes', COUNT(*) FROM orders
UNION ALL SELECT 'Produits', COUNT(*) FROM products
UNION ALL SELECT 'Gammes de produits', COUNT(*) FROM productlines;
"""

df_counts = pd.read_sql(query_counts, conn)

plt.figure(figsize=(9, 4.8))
plt.bar(df_counts["Element"], df_counts["Total"])
plt.xticks(rotation=30, ha="right")
plt.title("Nombre d’enregistrements par entité (ClassicModels)")
plt.ylabel("Total")
plt.tight_layout()
plt.show()


# ======================================================
# GRAPHIQUE 1 : Répartition des clients par pays
# ======================================================

query_clients_pays = """
SELECT country AS Pays, COUNT(*) AS Clients
FROM customers
GROUP BY country
ORDER BY Clients DESC;
"""

df = pd.read_sql(query_clients_pays, conn)

plt.figure(figsize=(10, 5))
plt.bar(df["Pays"], df["Clients"])
plt.xticks(rotation=45, ha="right")
plt.title("Répartition des clients par pays")
plt.ylabel("Nombre de clients")
plt.tight_layout()
plt.show()


# ======================================================
# GRAPHIQUE 2 : Commandes par statut
# ======================================================

query_status = """
SELECT status AS Statut, COUNT(*) AS Commandes
FROM orders
GROUP BY status
ORDER BY Commandes DESC;
"""

df_status = pd.read_sql(query_status, conn)

plt.figure(figsize=(6, 4))
plt.bar(df_status["Statut"], df_status["Commandes"])
plt.title("Commandes par statut")
plt.ylabel("Nombre de commandes")
plt.tight_layout()
plt.show()


# ======================================================
# GRAPHIQUE 3 : Chiffre d’affaires par gamme de produits
# ======================================================
# CA = somme(quantityOrdered * priceEach)
# On relie: productlines -> products -> orderdetails
# ======================================================

query_ca_gamme = """
SELECT pl.productLine AS Gamme,
       SUM(od.quantityOrdered * od.priceEach) AS Chiffre_affaires
FROM productlines pl
JOIN products p      ON p.productLine = pl.productLine
JOIN orderdetails od ON od.productCode = p.productCode
GROUP BY pl.productLine
ORDER BY Chiffre_affaires DESC;
"""

df_line = pd.read_sql(query_ca_gamme, conn)

plt.figure(figsize=(8, 4))
plt.bar(df_line["Gamme"], df_line["Chiffre_affaires"])
plt.xticks(rotation=30, ha="right")
plt.title("Chiffre d’affaires par gamme de produits")
plt.ylabel("Chiffre d’affaires")
plt.tight_layout()
plt.show()


# ======================================================
# GRAPHIQUE 4 : Top 10 produits les plus vendus (en quantité)
# ======================================================

query_top_produits = """
SELECT p.productName AS Produit,
       SUM(od.quantityOrdered) AS Quantite
FROM products p
JOIN orderdetails od ON od.productCode = p.productCode
GROUP BY p.productCode, p.productName
ORDER BY Quantite DESC
LIMIT 10;
"""

df_products = pd.read_sql(query_top_produits, conn)

plt.figure(figsize=(8, 5))
plt.barh(df_products["Produit"], df_products["Quantite"])
plt.title("Top 10 produits les plus vendus")
plt.xlabel("Quantité vendue")
plt.tight_layout()
plt.show()


# ======================================================
# GRAPHIQUE 5 : Top 5 clients par chiffre d’affaires
# ======================================================
# On relie: customers -> orders -> orderdetails
# ======================================================

query_top_clients = """
SELECT c.customerName AS Client,
       SUM(od.quantityOrdered * od.priceEach) AS Chiffre_affaires
FROM customers c
JOIN orders o        ON o.customerNumber = c.customerNumber
JOIN orderdetails od ON od.orderNumber = o.orderNumber
GROUP BY c.customerNumber, c.customerName
ORDER BY Chiffre_affaires DESC
LIMIT 5;
"""

df_clients = pd.read_sql(query_top_clients, conn)

plt.figure(figsize=(8, 4))
plt.bar(df_clients["Client"], df_clients["Chiffre_affaires"])
plt.xticks(rotation=30, ha="right")
plt.title("Top 5 clients par chiffre d’affaires")
plt.ylabel("Chiffre d’affaires")
plt.tight_layout()
plt.show()



# 2) Fermeture de la connexion 
# ======================================================

conn.close()



















