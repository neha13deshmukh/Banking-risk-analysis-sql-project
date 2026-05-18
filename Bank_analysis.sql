--               BANKING RISK ANALYSIS PROJECT 

-- Step 0: Create Database
CREATE DATABASE bank_project;
USE bank_project;

SET SQL_SAFE_UPDATES = 0;

-- =========================
-- Step 1: Create Staging Table
-- =========================

/* Creating a staging table to preserve raw data, 
   We Perform all cleaning operations on staging table
   instead of original data.
*/

CREATE TABLE bank_staging LIKE bank_data;

INSERT INTO bank_staging
SELECT * FROM bank_data;

SELECT * FROM bank_staging;

-- ====================
-- DATA CLEANING STEPS
-- ===================

-- 1. Check duplicates
-- 2. Standardize data
-- 3. Handle missing values
-- 4. Validate business inconsistencies
-- 5. Perform EDA & Risk Analysis

-- ==========================
-- STEP 2 : CHECK DUPLICATES
-- ==========================

-- Checking duplicate rows using ROW_NUMBER()

SELECT *
FROM(
SELECT *,
ROW_NUMBER() OVER(
PARTITION BY 
Account_ID,
Customer_Name,
Age,
Gender,
Account_Type,
Balance,
Transaction_Amount,
Transaction_Type,
Transaction_Date,
Branch,
IFSC_Code,
Loan_Status,
Credit_Score,
KYC_Status,
Account_Status
) AS row_num
FROM bank_staging
) duplicates
WHERE row_num > 1;

-- No exact duplicate rows found.

-- Lets check Duplicate account_id Details 

SELECT *
FROM bank_staging
WHERE Account_ID = 'A10797';
--  Account_ID A10797 appears Multiple times but the other details are different.

-- =========================
-- STEP 3 : STANDARDIZE DATA
-- =========================

-- Removing leading and trailing spaces, i.e (EXTRA SPACES)


UPDATE bank_staging
SET
Account_ID = TRIM(Account_ID),
Customer_Name = TRIM(Customer_Name),
Age = TRIM(Age),
Gender = TRIM(Gender),
Account_Type = TRIM(Account_Type),
Transaction_Type = TRIM(Transaction_Type),
Branch = TRIM(Branch),
IFSC_Code = TRIM(IFSC_Code),
Loan_Status = TRIM(Loan_Status),
KYC_Status = TRIM(KYC_Status),
Account_Status = TRIM(Account_Status);

-- ================================
-- STEP 4 : HANDLE MISSING VALUES
-- ================================

-- Checking blank Account_ID
SELECT *
FROM bank_staging
WHERE Account_ID IS NULL
OR Account_ID = '';

-- Converting Blank values into NULL
UPDATE bank_staging
SET Account_ID = NULL
WHERE Account_ID = '';

-- Removing rows with missing Account_ID, because Account_ID is an important identifier.
DELETE FROM bank_staging
WHERE Account_ID IS NULL;

-- Customer_Name

SELECT *
FROM bank_staging
WHERE Customer_Name IS NULL
OR Customer_Name = '';

-- Convert blanks to NULL

UPDATE bank_staging
SET Customer_Name = NULL
WHERE Customer_Name = '';

-- Filling missing customer_name using same Account_ID

UPDATE bank_staging t1
JOIN bank_staging t2
ON t1.Account_ID = t2.Account_ID
SET t1.Customer_Name = t2.Customer_Name
WHERE t1.Customer_Name IS NULL
AND t2.Customer_Name IS NOT NULL;

-- In Age there are blank rows lets check and update blank to null

SELECT *
FROM bank_staging
WHERE Age IS NULL
OR Age = '';

-- Convert blanks to NULL

UPDATE bank_staging
SET Age = NULL
WHERE Age = '';

-- Filling missing Age using same Account_ID & Customer_Name

UPDATE bank_staging t1
JOIN bank_staging t2
ON t1.Account_ID = t2.Account_ID
AND t1.Customer_Name = t2.Customer_Name
SET t1.Age = t2.Age
WHERE t1.Age IS NULL
AND t2.Age IS NOT NULL;

-- Check min and max age

SELECT MIN(Age), MAX(Age)
FROM bank_staging;

-- Gender lets check null or blank values for gender 
SELECT gender
FROM bank_staging
WHERE Gender IS NULL
OR Gender = '';

-- Convert blanks to NULL

UPDATE bank_staging
SET Gender = NULL
WHERE Gender = '';

-- Standardizing Gender values

UPDATE bank_staging
SET Gender =
CASE
WHEN LOWER(Gender) = 'male' THEN 'Male'
WHEN LOWER(Gender) = 'female' THEN 'Female'
WHEN LOWER(Gender) = 'other' THEN 'Other'
ELSE Gender
END;

-- Filling missing Gender using same Account_ID + Customer_Name

UPDATE bank_staging t1
JOIN bank_staging t2
ON t1.Account_ID = t2.Account_ID
AND t1.Customer_Name = t2.Customer_Name
SET t1.Gender = t2.Gender
WHERE t1.Gender IS NULL
AND t2.Gender IS NOT NULL;

-- Checking inconsistency

SELECT Customer_Name,
COUNT(DISTINCT Gender) as gender_count
FROM bank_staging
GROUP BY Customer_Name
HAVING COUNT(DISTINCT Gender) > 1;


-- ----------------
-- Account_Type
-- ----------------

SELECT *
FROM bank_staging
WHERE Account_Type IS NULL
OR Account_Type = '';

UPDATE bank_staging
SET Account_Type = NULL
WHERE Account_Type = '';

-- ------------------------------------------------------------
-- Transaction_Type
-- ------------------------------------------------------------

SELECT *
FROM bank_staging
WHERE Transaction_Type IS NULL
OR Transaction_Type = '';

UPDATE bank_staging
SET Transaction_Type = NULL
WHERE Transaction_Type = '';

-- ------------------------------------------------------------
-- Branch
-- ------------------------------------------------------------

SELECT *
FROM bank_staging
WHERE Branch IS NULL
OR Branch = '';

UPDATE bank_staging
SET Branch = NULL
WHERE Branch = '';

-- ------------------------------------------------------------
-- IFSC_Code
-- ------------------------------------------------------------

SELECT *
FROM bank_staging
WHERE IFSC_Code IS NULL
OR IFSC_Code = '';

UPDATE bank_staging
SET IFSC_Code = NULL
WHERE IFSC_Code = '';

-- ------------------------------------------------------------
-- Loan_Status
-- ------------------------------------------------------------

SELECT *
FROM bank_staging
WHERE Loan_Status IS NULL
OR Loan_Status = '';

UPDATE bank_staging
SET Loan_Status = NULL
WHERE Loan_Status = '';

-- ------------------------------------------------------------
-- KYC_Status
-- ------------------------------------------------------------

SELECT *
FROM bank_staging
WHERE KYC_Status IS NULL
OR KYC_Status = '';

UPDATE bank_staging
SET KYC_Status = NULL
WHERE KYC_Status = '';

-- ------------------------------------------------------------
-- Account_Status
-- ------------------------------------------------------------

SELECT *
FROM bank_staging
WHERE Account_Status IS NULL
OR Account_Status = '';

UPDATE bank_staging
SET Account_Status = NULL
WHERE Account_Status = '';

-- ============================================================
-- STEP 5 : BUSINESS VALIDATION & DATA CONSISTENCY CHECKS
-- ============================================================

/*
Now the basic cleaning is done.

Next step is validating business logic.
Here we check whether the banking data actually makes sense.

*/

-- ============================================================
-- TRANSACTION TYPE VALIDATION
-- ============================================================

/*
If Transaction_Amount is negative,
then Transaction_Type should normally be Debit.

If amount is positive,
then Transaction_Type should normally be Credit.

This query helps identify inconsistent transaction records.
*/

SELECT *
FROM bank_staging
WHERE (Transaction_Amount < 0 AND Transaction_Type = 'Credit')
OR (Transaction_Amount > 0 AND Transaction_Type = 'Debit');

-- FIXING TRANSACTION TYPE INCONSISTENCY

-- Now standardizing Transaction_Type based on Transaction_Amount.

UPDATE bank_staging
SET Transaction_Type =
CASE
WHEN Transaction_Amount < 0 THEN 'Debit'
WHEN Transaction_Amount > 0 THEN 'Credit'
ELSE Transaction_Type
END
WHERE Transaction_Amount IS NOT NULL;

-- ==============================
-- KYC vs LOAN STATUS VALIDATION
-- ==============================

/*
Checking inconsistent loan approvals.

Examples:
- KYC Pending but Loan Approved
- KYC Rejected but Loan Approved
*/

SELECT *
FROM bank_staging
WHERE (KYC_Status = 'Pending' AND Loan_Status = 'Approved')
OR (KYC_Status = 'Rejected' AND Loan_Status = 'Approved');

-- ============================================================
-- FIXING LOAN STATUS BASED ON KYC STATUS
-- ============================================================

/*
If KYC is Rejected or Pending,
Loan_Status should not remain Approved.
*/

UPDATE bank_staging
SET Loan_Status =
CASE
WHEN KYC_Status = 'Rejected' THEN 'Rejected'
WHEN KYC_Status = 'Pending' THEN 'Pending'
ELSE Loan_Status
END
WHERE Loan_Status = 'Approved';

-- VERIFY UPDATED LOAN STATUS

SELECT *
FROM bank_staging
WHERE (KYC_Status = 'Pending' AND Loan_Status = 'Approved')
OR (KYC_Status = 'Rejected' AND Loan_Status = 'Approved');

-- ========================
-- NEGATIVE BALANCE CHECK
-- ========================

SELECT * 
FROM bank_staging
WHERE Balance < 0;

-- ============================================================
-- STEP 6 : EXPLORATORY DATA ANALYSIS (EDA)
-- ============================================================
-- Now, Performing analysis based on the problem statements.

-- 1. IDENTIFY HIGH-RISK CUSTOMERS

/*
High-risk customers can be:
- low credit score
- negative balance
- rejected loans
- dormant accounts
*/
SELECT Account_ID, Customer_Name,Balance,Credit_Score,Loan_Status,Account_Status
FROM bank_staging
WHERE Credit_Score < 600
OR Balance < 0
OR Loan_Status = 'Rejected'
OR Account_Status = 'Dormant';

-- 2. DETECT FRAUDULENT TRANSACTIONS

/*
 If transaction amount is greater than 3 times the average transaction amount,
 then it may be suspicious.
*/

WITH avg_transaction AS
(
SELECT AVG(Transaction_Amount) AS avg_amt
FROM bank_staging
)

SELECT
b.Account_ID,
b.Customer_Name,
b.Transaction_Amount,
b.Transaction_Type
FROM bank_staging b
JOIN avg_transaction a
ON ABS(b.Transaction_Amount) > a.avg_amt * 3;

-- MULTIPLE TRANSACTIONS BY SAME ACCOUNT
/*
Accounts having unusually high number of transactions.
*/

SELECT Account_ID,
COUNT(*) AS Total_Transactions
FROM bank_staging
GROUP BY Account_ID
HAVING COUNT(*) > 3
ORDER BY Total_Transactions DESC;

-- 3. ANALYZE CUSTOMER SEGMENTATION
-- Segmenting customers based on account balance.

SELECT Account_ID,Customer_Name,Balance,
CASE
WHEN Balance < 50000 THEN 'Low Balance Customer'
WHEN Balance BETWEEN 50000 AND 150000 THEN 'Middle Balance Customer'
ELSE 'High Value Customer'
END AS Customer_Segment

FROM bank_staging;

-- 4. IMPROVE LOAN APPROVAL DECISIONS
/*
Checking loan eligibility using:
- Credit Score
- Balance
- KYC Status
*/

SELECT Account_ID,Customer_Name,Credit_Score,Balance,KYC_Status,

CASE
WHEN Credit_Score >= 750 AND Balance >= 50000 AND KYC_Status = 'Verified'
	THEN 'Eligible'

WHEN Credit_Score BETWEEN 600 AND 749	
	THEN 'Review '

ELSE 'Rejected'
END AS Loan_Approval_Status
FROM bank_staging;

-- 5. MONITOR ACCOUNT HEALTH & INACTIVITY
-- Checking dormant accounts.
SELECT
Account_ID,
Customer_Name,
Account_Status
FROM bank_staging
WHERE Account_Status = 'Dormant';

/*
Healthy accounts:
- Active accounts
- Good balance
- Good credit score
*/

SELECT Account_ID,Customer_Name,Balance,Credit_Score,Account_Status
FROM bank_staging
WHERE Account_Status = 'Active' AND Balance > 50000 AND Credit_Score > 700;


-- 6. EVALUATE BRANCH PERFORMANCE
-- Branch-wise customer count and total deposits.

SELECT
Branch,
COUNT(Account_ID) AS Total_Customers,
SUM(Balance) AS Total_Deposits
FROM bank_staging
WHERE Branch IS NOT NULL
GROUP BY Branch
ORDER BY Total_Deposits DESC;
