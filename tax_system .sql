-- ============================================================
-- TAX COLLECTION & REVENUE MANAGEMENT SYSTEM
-- Database: MySQL
-- Author: Database Project
-- ============================================================
DROP DATABASE IF EXISTS tax_revenue_db;
CREATE DATABASE tax_revenue_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE tax_revenue_db;

-- -------------------------------------------------------
-- 1. TABLE DEFINITIONS (DDL)
-- -------------------------------------------------------

-- 1.1 TAX CATEGORIES
CREATE TABLE tax_categories (
    category_id     INT          AUTO_INCREMENT PRIMARY KEY,
    category_name   VARCHAR(100) NOT NULL UNIQUE,
    description     TEXT,
    tax_rate        DECIMAL(5,2) NOT NULL CHECK (tax_rate >= 0 AND tax_rate <= 100),
    is_active       TINYINT(1)   NOT NULL DEFAULT 1,
    created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 1.2 INDIVIDUAL TAXPAYERS
CREATE TABLE individual_taxpayers (
    taxpayer_id         INT           AUTO_INCREMENT PRIMARY KEY,
    national_id         VARCHAR(20)   NOT NULL UNIQUE,
    first_name          VARCHAR(100)  NOT NULL,
    last_name           VARCHAR(100)  NOT NULL,
    date_of_birth       DATE          NOT NULL,
    email               VARCHAR(150)  NOT NULL UNIQUE,
    phone               VARCHAR(20),
    address             TEXT,
    annual_income       DECIMAL(15,2) NOT NULL DEFAULT 0.00 CHECK (annual_income >= 0),
    registration_date   DATE          NOT NULL DEFAULT (CURRENT_DATE),
    is_active           TINYINT(1)    NOT NULL DEFAULT 1,
    password_hash       VARCHAR(256)  NOT NULL  -- SHA-256 hashed password
) ENGINE=InnoDB;

-- 1.3 CORPORATE TAXPAYERS
CREATE TABLE corporate_taxpayers (
    corp_id             INT           AUTO_INCREMENT PRIMARY KEY,
    registration_number VARCHAR(50)   NOT NULL UNIQUE,
    company_name        VARCHAR(200)  NOT NULL,
    industry_sector     VARCHAR(100),
    contact_person      VARCHAR(200),
    email               VARCHAR(150)  NOT NULL UNIQUE,
    phone               VARCHAR(20),
    address             TEXT,
    annual_revenue      DECIMAL(18,2) NOT NULL DEFAULT 0.00 CHECK (annual_revenue >= 0),
    registration_date   DATE          NOT NULL DEFAULT (CURRENT_DATE),
    is_active           TINYINT(1)    NOT NULL DEFAULT 1,
    password_hash       VARCHAR(256)  NOT NULL
) ENGINE=InnoDB;

-- 1.4 TAX OFFICERS
CREATE TABLE tax_officers (
    officer_id      INT          AUTO_INCREMENT PRIMARY KEY,
    employee_id     VARCHAR(20)  NOT NULL UNIQUE,
    full_name       VARCHAR(200) NOT NULL,
    email           VARCHAR(150) NOT NULL UNIQUE,
    department      VARCHAR(100),
    role            ENUM('admin','auditor','collector','supervisor') NOT NULL DEFAULT 'collector',
    hire_date       DATE         NOT NULL,
    is_active       TINYINT(1)   NOT NULL DEFAULT 1,
    password_hash   VARCHAR(256) NOT NULL
) ENGINE=InnoDB;

-- 1.5 TAX ASSESSMENTS
CREATE TABLE tax_assessments (
    assessment_id       INT              AUTO_INCREMENT PRIMARY KEY,
    taxpayer_type       ENUM('individual','corporate') NOT NULL,
    individual_id       INT              NULL,
    corporate_id        INT              NULL,
    category_id         INT              NOT NULL,
    officer_id          INT              NOT NULL,
    tax_year            YEAR             NOT NULL,
    taxable_income      DECIMAL(18,2)    NOT NULL CHECK (taxable_income >= 0),
    tax_rate_applied    DECIMAL(5,2)     NOT NULL CHECK (tax_rate_applied >= 0),
    assessed_amount     DECIMAL(18,2)    NOT NULL CHECK (assessed_amount >= 0),
    assessment_date     DATE             NOT NULL DEFAULT (CURRENT_DATE),
    due_date            DATE             NOT NULL,
    status              ENUM('pending','paid','overdue','disputed','cancelled') NOT NULL DEFAULT 'pending',
    notes               TEXT,
    CONSTRAINT fk_assess_individual FOREIGN KEY (individual_id)
        REFERENCES individual_taxpayers(taxpayer_id) ON DELETE CASCADE,
    CONSTRAINT fk_assess_corporate  FOREIGN KEY (corporate_id)
        REFERENCES corporate_taxpayers(corp_id) ON DELETE CASCADE,
    CONSTRAINT fk_assess_category   FOREIGN KEY (category_id)
        REFERENCES tax_categories(category_id),
    CONSTRAINT fk_assess_officer    FOREIGN KEY (officer_id)
        REFERENCES tax_officers(officer_id),
    CONSTRAINT chk_taxpayer_ref CHECK (
        (taxpayer_type = 'individual' AND individual_id IS NOT NULL AND corporate_id IS NULL)
        OR
        (taxpayer_type = 'corporate' AND corporate_id IS NOT NULL AND individual_id IS NULL)
    )
) ENGINE=InnoDB;

-- 1.6 PAYMENTS
CREATE TABLE payments (
    payment_id          INT              AUTO_INCREMENT PRIMARY KEY,
    assessment_id       INT              NOT NULL,
    amount_paid         DECIMAL(18,2)    NOT NULL CHECK (amount_paid > 0),
    payment_date        DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    payment_method      ENUM('bank_transfer','credit_card','cash','cheque','online') NOT NULL,
    reference_number    VARCHAR(100)     NOT NULL UNIQUE,
    processed_by        INT              NOT NULL,
    receipt_issued      TINYINT(1)       NOT NULL DEFAULT 0,
    notes               TEXT,
    CONSTRAINT fk_pay_assessment FOREIGN KEY (assessment_id)
        REFERENCES tax_assessments(assessment_id),
    CONSTRAINT fk_pay_officer    FOREIGN KEY (processed_by)
        REFERENCES tax_officers(officer_id)
) ENGINE=InnoDB;

-- 1.7 PENALTIES
CREATE TABLE penalties (
    penalty_id          INT              AUTO_INCREMENT PRIMARY KEY,
    assessment_id       INT              NOT NULL,
    penalty_type        ENUM('late_filing','late_payment','underpayment','fraud') NOT NULL,
    penalty_rate        DECIMAL(5,2)     NOT NULL CHECK (penalty_rate >= 0),
    penalty_amount      DECIMAL(18,2)    NOT NULL CHECK (penalty_amount >= 0),
    interest_amount     DECIMAL(18,2)    NOT NULL DEFAULT 0.00,
    issue_date          DATE             NOT NULL DEFAULT (CURRENT_DATE),
    waived              TINYINT(1)       NOT NULL DEFAULT 0,
    waived_by           INT              NULL,
    waiver_reason       TEXT,
    CONSTRAINT fk_pen_assessment FOREIGN KEY (assessment_id)
        REFERENCES tax_assessments(assessment_id),
    CONSTRAINT fk_pen_officer    FOREIGN KEY (waived_by)
        REFERENCES tax_officers(officer_id)
) ENGINE=InnoDB;

-- 1.8 AUDIT LOG (Security & Traceability)
CREATE TABLE audit_log (
    log_id          BIGINT       AUTO_INCREMENT PRIMARY KEY,
    table_name      VARCHAR(100) NOT NULL,
    action          ENUM('INSERT','UPDATE','DELETE') NOT NULL,
    record_id       INT          NOT NULL,
    changed_by      VARCHAR(200),
    change_time     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    old_values      JSON,
    new_values      JSON
) ENGINE=InnoDB;

-- -------------------------------------------------------
-- 2. INDEXES FOR PERFORMANCE
-- -------------------------------------------------------
CREATE INDEX idx_individual_national_id   ON individual_taxpayers(national_id);
CREATE INDEX idx_individual_email         ON individual_taxpayers(email);
CREATE INDEX idx_corporate_reg_number     ON corporate_taxpayers(registration_number);
CREATE INDEX idx_assessment_taxpayer_year ON tax_assessments(taxpayer_type, tax_year);
CREATE INDEX idx_assessment_status        ON tax_assessments(status);
CREATE INDEX idx_assessment_due_date      ON tax_assessments(due_date);
CREATE INDEX idx_payment_date             ON payments(payment_date);
CREATE INDEX idx_payment_assessment       ON payments(assessment_id);
CREATE INDEX idx_penalty_assessment       ON penalties(assessment_id);
CREATE INDEX idx_audit_table_action       ON audit_log(table_name, action);

-- -------------------------------------------------------
-- 3. SAMPLE DATA INSERTION
-- -------------------------------------------------------

-- 3.1 Tax Categories (6 records)
INSERT INTO tax_categories (category_name, description, tax_rate) VALUES
('Personal Income Tax',      'Tax on individual earned income',              15.00),
('Corporate Income Tax',     'Tax on corporate profits',                     22.50),
('Value Added Tax (VAT)',     'Consumption tax on goods and services',        14.00),
('Capital Gains Tax',        'Tax on profit from asset sales',               10.00),
('Withholding Tax',          'Tax withheld at source of income',              5.00),
('Property Tax',             'Annual tax on real estate holdings',            1.50);

-- 3.2 Tax Officers (5 records)
INSERT INTO tax_officers (employee_id, full_name, email, department, role, hire_date, password_hash) VALUES
('EMP001', 'Ahmed Hassan',     'a.hassan@taxdept.gov',    'Assessment',  'admin',      '2018-03-15', SHA2('P@ssw0rd!001', 256)),
('EMP002', 'Sara Mohamed',     's.mohamed@taxdept.gov',   'Collections', 'collector',  '2019-07-01', SHA2('P@ssw0rd!002', 256)),
('EMP003', 'Khalid Ibrahim',   'k.ibrahim@taxdept.gov',   'Audit',       'auditor',    '2020-01-20', SHA2('P@ssw0rd!003', 256)),
('EMP004', 'Nadia Youssef',    'n.youssef@taxdept.gov',   'Collections', 'collector',  '2021-06-10', SHA2('P@ssw0rd!004', 256)),
('EMP005', 'Omar Farouk',      'o.farouk@taxdept.gov',    'Compliance',  'supervisor', '2017-09-05', SHA2('P@ssw0rd!005', 256));

-- 3.3 Individual Taxpayers (20 records)
INSERT INTO individual_taxpayers
    (national_id, first_name, last_name, date_of_birth, email, phone, address, annual_income, registration_date, password_hash)
VALUES
('NID001', 'Mohamed',  'Ali',       '1985-04-12', 'm.ali@email.com',       '01012345001', 'Cairo, Nasr City',         95000.00,  '2020-01-10', SHA2('TaxUser001!', 256)),
('NID002', 'Fatima',   'Hassan',    '1990-08-23', 'f.hassan@email.com',    '01012345002', 'Alexandria, Sidi Gaber',   120000.00, '2020-02-14', SHA2('TaxUser002!', 256)),
('NID003', 'Ahmed',    'Salah',     '1978-11-05', 'a.salah@email.com',     '01012345003', 'Giza, Dokki',              75000.00,  '2020-03-08', SHA2('TaxUser003!', 256)),
('NID004', 'Nour',     'Ibrahim',   '1995-02-18', 'n.ibrahim@email.com',   '01012345004', 'Cairo, Heliopolis',        55000.00,  '2020-04-22', SHA2('TaxUser004!', 256)),
('NID005', 'Tarek',    'Mostafa',   '1982-07-30', 't.mostafa@email.com',   '01012345005', 'Mansoura, City Center',    140000.00, '2020-05-17', SHA2('TaxUser005!', 256)),
('NID006', 'Rania',    'Kamal',     '1988-09-14', 'r.kamal@email.com',     '01012345006', 'Cairo, Maadi',             200000.00, '2020-06-03', SHA2('TaxUser006!', 256)),
('NID007', 'Hassan',   'Mahmoud',   '1975-12-01', 'h.mahmoud@email.com',   '01012345007', 'Luxor, East Bank',         68000.00,  '2020-07-19', SHA2('TaxUser007!', 256)),
('NID008', 'Dina',     'Samir',     '1993-03-27', 'd.samir@email.com',     '01012345008', 'Cairo, Zamalek',           180000.00, '2020-08-11', SHA2('TaxUser008!', 256)),
('NID009', 'Youssef',  'Nabil',     '1987-06-09', 'y.nabil@email.com',     '01012345009', 'Suez, Port Tewfik',        88000.00,  '2020-09-25', SHA2('TaxUser009!', 256)),
('NID010', 'Hana',     'Adel',      '1991-10-16', 'hana.adel@email.com',   '01012345010', 'Ismailia, El Hay',         62000.00,  '2020-10-30', SHA2('TaxUser010!', 256)),
('NID011', 'Sherif',   'Fouad',     '1980-01-22', 's.fouad@email.com',     '01012345011', 'Alexandria, Montaza',      95000.00,  '2021-01-05', SHA2('TaxUser011!', 256)),
('NID012', 'Mona',     'Khalil',    '1996-05-03', 'm.khalil@email.com',    '01012345012', 'Cairo, October City',      48000.00,  '2021-02-18', SHA2('TaxUser012!', 256)),
('NID013', 'Kareem',   'Ezzat',     '1983-08-15', 'k.ezzat@email.com',     '01012345013', 'Tanta, Gharbeya',          110000.00, '2021-03-22', SHA2('TaxUser013!', 256)),
('NID014', 'Layla',    'Mansour',   '1989-11-28', 'l.mansour@email.com',   '01012345014', 'Aswan, Khazan',            72000.00,  '2021-04-14', SHA2('TaxUser014!', 256)),
('NID015', 'Amr',      'Zaki',      '1977-02-07', 'a.zaki@email.com',      '01012345015', 'Cairo, Shubra',            130000.00, '2021-05-09', SHA2('TaxUser015!', 256)),
('NID016', 'Noha',     'Wael',      '1994-04-19', 'n.wael@email.com',      '01012345016', 'Faiyum, City',             54000.00,  '2021-06-27', SHA2('TaxUser016!', 256)),
('NID017', 'Bassem',   'Ragab',     '1981-07-11', 'b.ragab@email.com',     '01012345017', 'Port Said, El Dawahy',     165000.00, '2021-07-31', SHA2('TaxUser017!', 256)),
('NID018', 'Iman',     'Shawki',    '1992-09-24', 'i.shawki@email.com',    '01012345018', 'Cairo, Imbaba',            79000.00,  '2021-08-15', SHA2('TaxUser018!', 256)),
('NID019', 'Samir',    'Ghoneim',   '1979-12-05', 's.ghoneim@email.com',   '01012345019', 'Alexandria, Agami',        91000.00,  '2021-09-20', SHA2('TaxUser019!', 256)),
('NID020', 'Yasmin',   'Tawfik',    '1997-03-31', 'y.tawfik@email.com',    '01012345020', 'Cairo, New Cairo',         43000.00,  '2021-10-12', SHA2('TaxUser020!', 256));

-- 3.4 Corporate Taxpayers (20 records)
INSERT INTO corporate_taxpayers
    (registration_number, company_name, industry_sector, contact_person, email, phone, address, annual_revenue, registration_date, password_hash)
VALUES
('CRP001', 'NileTech Solutions',          'Information Technology', 'Ahmed Gabr',     'info@niletech.eg',        '0223456001', 'Cairo, Smart Village',       12500000.00, '2019-01-15', SHA2('CorpPass001!', 256)),
('CRP002', 'Delta Pharma Co.',            'Pharmaceuticals',        'Heba Saad',      'heba@deltapharma.eg',     '0223456002', 'Giza, 6th October City',     8700000.00,  '2019-03-22', SHA2('CorpPass002!', 256)),
('CRP003', 'Nasser Steel Industries',     'Manufacturing',          'Mostafa Nasser', 'info@nassersteel.eg',     '0223456003', 'Helwan Industrial Zone',     45000000.00, '2019-05-10', SHA2('CorpPass003!', 256)),
('CRP004', 'SunRise Tourism Group',       'Tourism & Hospitality',  'Laila Omar',     'laila@sunrisetourism.eg', '0223456004', 'Sharm El Sheikh',            6200000.00,  '2019-07-18', SHA2('CorpPass004!', 256)),
('CRP005', 'Green Valley Agriculture',    'Agriculture',            'Ramadan Said',   'info@greenvalley.eg',     '0223456005', 'Fayoum, Agricultural Area',  3100000.00,  '2019-09-05', SHA2('CorpPass005!', 256)),
('CRP006', 'Cairo Motors Ltd.',           'Automotive',             'Wael Hamdan',    'wael@cairomotors.eg',     '0223456006', 'Cairo, Ring Road',           18900000.00, '2019-11-12', SHA2('CorpPass006!', 256)),
('CRP007', 'AlAhly Bank Egypt',           'Banking & Finance',      'Rasha Badr',     'rasha@alahlybank.eg',     '0223456007', 'Cairo, Downtown',            95000000.00, '2020-01-08', SHA2('CorpPass007!', 256)),
('CRP008', 'MedCare Hospitals',           'Healthcare',             'Dr. Nada Helmy', 'nada@medcare.eg',         '0223456008', 'Alexandria, Miami',          22000000.00, '2020-03-15', SHA2('CorpPass008!', 256)),
('CRP009', 'Pyramid Cement Works',        'Construction Materials', 'Ibrahim Zayed',  'info@pyramidcement.eg',   '0223456009', 'Suez, Industrial Zone',      38000000.00, '2020-05-20', SHA2('CorpPass009!', 256)),
('CRP010', 'EgyptAir Cargo',              'Logistics & Transport',  'Capt. Samy',     'cargo@egyptaircargo.eg',  '0223456010', 'Cairo Airport',              71000000.00, '2020-07-25', SHA2('CorpPass010!', 256)),
('CRP011', 'SafoTex Textile',             'Textile & Garments',     'Maha Safwat',    'info@safotex.eg',         '0223456011', 'Mahalla El Kubra',           14000000.00, '2020-09-01', SHA2('CorpPass011!', 256)),
('CRP012', 'HorizonNet ISP',              'Telecommunications',     'Sherif Galal',   'info@horizonnet.eg',      '0223456012', 'Cairo, Nasr City',           29000000.00, '2020-11-14', SHA2('CorpPass012!', 256)),
('CRP013', 'Nile Energy Solutions',       'Energy',                 'Eng. Hani',      'hani@nileenergy.eg',      '0223456013', 'Cairo, New Cairo',           53000000.00, '2021-01-19', SHA2('CorpPass013!', 256)),
('CRP014', 'FreshFarm Foods',             'Food & Beverage',        'Amina Lotfy',    'amina@freshfarm.eg',      '0223456014', 'Ismailia, Industrial Area',  9800000.00,  '2021-03-27', SHA2('CorpPass014!', 256)),
('CRP015', 'BluePrint Architects',        'Construction',           'Eng. Nour',      'info@blueprint.eg',       '0223456015', 'Alexandria, Smouha',         7600000.00,  '2021-05-31', SHA2('CorpPass015!', 256)),
('CRP016', 'TechBridge Software',         'Software',               'Karim Medhat',   'info@techbridge.eg',      '0223456016', 'Cairo, Maadi',               5400000.00,  '2021-07-07', SHA2('CorpPass016!', 256)),
('CRP017', 'RedSea Fisheries',            'Fishing',                'Capt. Adel',     'info@redsea.eg',          '0223456017', 'Hurghada, Port',             4200000.00,  '2021-09-14', SHA2('CorpPass017!', 256)),
('CRP018', 'GoldenGrain Mills',           'Milling & Processing',   'Hassan Arafa',   'info@goldengrain.eg',     '0223456018', 'Beheira, Damanhur',          16500000.00, '2021-11-21', SHA2('CorpPass018!', 256)),
('CRP019', 'MediterMedia Group',          'Media & Publishing',     'Dalia Rashad',   'info@meditermedia.eg',    '0223456019', 'Cairo, Garden City',         11200000.00, '2022-01-10', SHA2('CorpPass019!', 256)),
('CRP020', 'SkyHigh Aviation Services',   'Aviation',               'Capt. Maged',    'maged@skyhigh.eg',        '0223456020', 'Cairo Airport Free Zone',    32000000.00, '2022-03-18', SHA2('CorpPass020!', 256));

-- 3.5 Tax Assessments (25 records)
INSERT INTO tax_assessments
    (taxpayer_type, individual_id, corporate_id, category_id, officer_id, tax_year, taxable_income, tax_rate_applied, assessed_amount, assessment_date, due_date, status)
VALUES
-- Individuals
('individual', 1,  NULL, 1, 2, 2023, 95000.00,   15.00, 14250.00,  '2024-01-15', '2024-03-31', 'paid'),
('individual', 2,  NULL, 1, 2, 2023, 120000.00,  15.00, 18000.00,  '2024-01-18', '2024-03-31', 'paid'),
('individual', 3,  NULL, 1, 3, 2023, 75000.00,   15.00, 11250.00,  '2024-01-20', '2024-03-31', 'paid'),
('individual', 4,  NULL, 1, 4, 2023, 55000.00,   15.00,  8250.00,  '2024-01-25', '2024-03-31', 'overdue'),
('individual', 5,  NULL, 1, 2, 2023, 140000.00,  15.00, 21000.00,  '2024-02-01', '2024-03-31', 'paid'),
('individual', 6,  NULL, 4, 1, 2023, 200000.00,  10.00, 20000.00,  '2024-02-05', '2024-04-30', 'paid'),
('individual', 7,  NULL, 1, 3, 2023, 68000.00,   15.00, 10200.00,  '2024-02-10', '2024-03-31', 'overdue'),
('individual', 8,  NULL, 1, 4, 2023, 180000.00,  15.00, 27000.00,  '2024-02-14', '2024-03-31', 'paid'),
('individual', 9,  NULL, 5, 2, 2023, 88000.00,    5.00,  4400.00,  '2024-02-18', '2024-04-30', 'pending'),
('individual', 10, NULL, 1, 2, 2023, 62000.00,   15.00,  9300.00,  '2024-02-22', '2024-03-31', 'pending'),
-- Corporates
('corporate', NULL,  1, 2, 1, 2023, 12500000.00, 22.50, 2812500.00, '2024-01-10', '2024-04-30', 'paid'),
('corporate', NULL,  2, 2, 1, 2023,  8700000.00, 22.50, 1957500.00, '2024-01-12', '2024-04-30', 'paid'),
('corporate', NULL,  3, 2, 3, 2023, 45000000.00, 22.50,10125000.00, '2024-01-14', '2024-04-30', 'paid'),
('corporate', NULL,  4, 3, 1, 2023,  6200000.00, 14.00,  868000.00, '2024-01-16', '2024-04-30', 'paid'),
('corporate', NULL,  5, 2, 5, 2023,  3100000.00, 22.50,  697500.00, '2024-01-19', '2024-04-30', 'overdue'),
('corporate', NULL,  6, 2, 1, 2023, 18900000.00, 22.50, 4252500.00, '2024-01-22', '2024-04-30', 'paid'),
('corporate', NULL,  7, 5, 3, 2023, 95000000.00,  5.00, 4750000.00, '2024-01-25', '2024-04-30', 'paid'),
('corporate', NULL,  8, 2, 1, 2023, 22000000.00, 22.50, 4950000.00, '2024-01-28', '2024-04-30', 'disputed'),
('corporate', NULL,  9, 2, 3, 2023, 38000000.00, 22.50, 8550000.00, '2024-01-30', '2024-04-30', 'paid'),
('corporate', NULL, 10, 2, 5, 2023, 71000000.00, 22.50,15975000.00, '2024-02-02', '2024-04-30', 'paid'),
('corporate', NULL, 11, 3, 2, 2023, 14000000.00, 14.00, 1960000.00, '2024-02-05', '2024-04-30', 'pending'),
('corporate', NULL, 12, 2, 1, 2023, 29000000.00, 22.50, 6525000.00, '2024-02-08', '2024-04-30', 'paid'),
('corporate', NULL, 13, 2, 3, 2023, 53000000.00, 22.50,11925000.00, '2024-02-12', '2024-04-30', 'paid'),
('corporate', NULL, 14, 3, 4, 2023,  9800000.00, 14.00, 1372000.00, '2024-02-15', '2024-04-30', 'overdue'),
('corporate', NULL, 15, 2, 1, 2023,  7600000.00, 22.50, 1710000.00, '2024-02-18', '2024-04-30', 'pending');

-- 3.6 Payments (20 records)
INSERT INTO payments (assessment_id, amount_paid, payment_date, payment_method, reference_number, processed_by)
VALUES
(1,  14250.00,  '2024-02-10 09:30:00', 'bank_transfer', 'REF-2024-00001', 2),
(2,  18000.00,  '2024-02-15 10:15:00', 'online',         'REF-2024-00002', 2),
(3,  11250.00,  '2024-02-20 11:00:00', 'bank_transfer', 'REF-2024-00003', 4),
(5,  21000.00,  '2024-02-25 14:00:00', 'credit_card',   'REF-2024-00004', 2),
(6,  20000.00,  '2024-03-01 09:45:00', 'bank_transfer', 'REF-2024-00005', 1),
(8,  27000.00,  '2024-03-05 10:30:00', 'online',         'REF-2024-00006', 4),
(11, 2812500.00,'2024-03-10 11:00:00', 'bank_transfer', 'REF-2024-00007', 1),
(12, 1957500.00,'2024-03-12 13:00:00', 'bank_transfer', 'REF-2024-00008', 1),
(13, 5000000.00,'2024-03-14 09:15:00', 'bank_transfer', 'REF-2024-00009', 3),
(13, 5125000.00,'2024-04-01 10:00:00', 'bank_transfer', 'REF-2024-00010', 3),
(14, 868000.00, '2024-03-18 11:30:00', 'bank_transfer', 'REF-2024-00011', 1),
(16, 4252500.00,'2024-03-20 14:15:00', 'online',         'REF-2024-00012', 4),
(17, 4750000.00,'2024-03-22 09:00:00', 'bank_transfer', 'REF-2024-00013', 2),
(19, 8550000.00,'2024-03-25 10:45:00', 'bank_transfer', 'REF-2024-00014', 1),
(20, 15975000.00,'2024-03-28 11:15:00','bank_transfer', 'REF-2024-00015', 3),
(22, 6525000.00,'2024-04-02 09:30:00', 'bank_transfer', 'REF-2024-00016', 1),
(23, 11925000.00,'2024-04-05 10:00:00','bank_transfer', 'REF-2024-00017', 3),
(6,  500.00,    '2024-04-08 14:00:00', 'cash',           'REF-2024-00018', 2),
(9,  4400.00,   '2024-04-10 11:00:00', 'credit_card',   'REF-2024-00019', 4),
(10, 9300.00,   '2024-04-12 09:00:00', 'online',         'REF-2024-00020', 2);

-- 3.7 Penalties (20 records)
INSERT INTO penalties (assessment_id, penalty_type, penalty_rate, penalty_amount, interest_amount, issue_date, waived)
VALUES
(4,  'late_payment', 2.00,   165.00,   82.50,  '2024-04-15', 0),
(7,  'late_payment', 2.00,   204.00,  102.00,  '2024-04-15', 0),
(15, 'late_filing',  5.00, 34875.00, 6975.00,  '2024-05-01', 0),
(24, 'late_payment', 2.00, 27440.00, 5488.00,  '2024-05-01', 0),
(18, 'underpayment', 3.00, 148500.00,29700.00, '2024-04-20', 0),
(11, 'late_filing',  1.00, 28125.00,  2812.50, '2024-02-05', 1),
(1,  'late_payment', 1.00,   142.50,   28.50,  '2024-04-05', 1),
(5,  'late_filing',  2.00,   420.00,   84.00,  '2024-03-01', 1),
(3,  'late_payment', 1.50,   168.75,   33.75,  '2024-04-01', 1),
(2,  'late_payment', 1.00,   180.00,   36.00,  '2024-03-01', 1),
(21, 'late_filing',  5.00, 98000.00, 19600.00, '2024-05-10', 0),
(25, 'late_payment', 2.00, 34200.00,  6840.00, '2024-05-15', 0),
(10, 'late_payment', 2.00,   186.00,   37.20,  '2024-04-20', 0),
(9,  'late_filing',  3.00,   132.00,   26.40,  '2024-05-01', 0),
(6,  'underpayment', 2.00,   400.00,   80.00,  '2024-04-10', 1),
(12, 'late_payment', 1.00, 19575.00,  3915.00, '2024-05-01', 1),
(8,  'late_payment', 1.50,   405.00,   81.00,  '2024-04-05', 1),
(13, 'late_filing',  2.00,202500.00, 40500.00, '2024-02-15', 1),
(16, 'late_payment', 1.00, 42525.00,  8505.00, '2024-05-01', 0),
(20, 'fraud',       10.00,1597500.00,319500.00,'2024-04-20', 0);

-- -------------------------------------------------------
-- 4. STORED PROCEDURES
-- -------------------------------------------------------

DELIMITER $$

-- 4.1: Register a new individual taxpayer
CREATE PROCEDURE sp_register_individual(
    IN p_national_id    VARCHAR(20),
    IN p_first_name     VARCHAR(100),
    IN p_last_name      VARCHAR(100),
    IN p_dob            DATE,
    IN p_email          VARCHAR(150),
    IN p_phone          VARCHAR(20),
    IN p_address        TEXT,
    IN p_income         DECIMAL(15,2),
    IN p_password       VARCHAR(100)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    START TRANSACTION;
    INSERT INTO individual_taxpayers
        (national_id, first_name, last_name, date_of_birth, email, phone, address, annual_income, password_hash)
    VALUES
        (p_national_id, p_first_name, p_last_name, p_dob, p_email, p_phone, p_address, p_income, SHA2(p_password, 256));
    COMMIT;
    SELECT LAST_INSERT_ID() AS new_taxpayer_id;
END$$

-- 4.2: Process a payment for an assessment
CREATE PROCEDURE sp_process_payment(
    IN p_assessment_id  INT,
    IN p_amount         DECIMAL(18,2),
    IN p_method         VARCHAR(20),
    IN p_reference      VARCHAR(100),
    IN p_officer_id     INT
)
BEGIN
    DECLARE v_assessed   DECIMAL(18,2);
    DECLARE v_paid       DECIMAL(18,2);
    DECLARE v_status     VARCHAR(20);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT assessed_amount, status
      INTO v_assessed, v_status
      FROM tax_assessments
     WHERE assessment_id = p_assessment_id
       FOR UPDATE;

    IF v_status = 'cancelled' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot pay a cancelled assessment.';
    END IF;

    SELECT COALESCE(SUM(amount_paid), 0)
      INTO v_paid
      FROM payments
     WHERE assessment_id = p_assessment_id;

    INSERT INTO payments (assessment_id, amount_paid, payment_method, reference_number, processed_by)
    VALUES (p_assessment_id, p_amount, p_method, p_reference, p_officer_id);

    -- If fully paid, mark assessment as paid
    IF (v_paid + p_amount) >= v_assessed THEN
        UPDATE tax_assessments
           SET status = 'paid'
         WHERE assessment_id = p_assessment_id;
    END IF;

    COMMIT;
    SELECT 'Payment processed successfully' AS result, (v_paid + p_amount) AS total_paid;
END$$

-- 4.3: Generate penalty for overdue assessment
CREATE PROCEDURE sp_generate_penalty(
    IN p_assessment_id  INT,
    IN p_penalty_type   VARCHAR(20),
    IN p_penalty_rate   DECIMAL(5,2)
)
BEGIN
    DECLARE v_assessed  DECIMAL(18,2);
    DECLARE v_amount    DECIMAL(18,2);
    DECLARE v_interest  DECIMAL(18,2);

    START TRANSACTION;

    SELECT assessed_amount INTO v_assessed
      FROM tax_assessments
     WHERE assessment_id = p_assessment_id;

    SET v_amount   = v_assessed * (p_penalty_rate / 100);
    SET v_interest = v_amount * 0.20;   -- 20% interest on penalty

    INSERT INTO penalties (assessment_id, penalty_type, penalty_rate, penalty_amount, interest_amount)
    VALUES (p_assessment_id, p_penalty_type, p_penalty_rate, v_amount, v_interest);

    UPDATE tax_assessments SET status = 'overdue'
     WHERE assessment_id = p_assessment_id AND status = 'pending';

    COMMIT;
    SELECT 'Penalty generated' AS result, v_amount AS penalty_amount, v_interest AS interest;
END$$

DELIMITER ;

DELIMITER $$
-- -------------------------------------------------------
-- TRIGGERS: individual_taxpayers
-- -------------------------------------------------------
CREATE TRIGGER trg_individual_after_insert
AFTER INSERT ON individual_taxpayers
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, action, record_id, changed_by, old_values, new_values)
    VALUES (
        'individual_taxpayers',
        'INSERT',
        NEW.taxpayer_id,
        USER(),
        NULL,
        JSON_OBJECT(
            'national_id',       NEW.national_id,
            'first_name',        NEW.first_name,
            'last_name',         NEW.last_name,
            'email',             NEW.email,
            'annual_income',     NEW.annual_income,
            'is_active',         NEW.is_active
        )
    );
END$$
 
CREATE TRIGGER trg_individual_after_update
AFTER UPDATE ON individual_taxpayers
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, action, record_id, changed_by, old_values, new_values)
    VALUES (
        'individual_taxpayers',
        'UPDATE',
        NEW.taxpayer_id,
        USER(),
        JSON_OBJECT(
            'email',         OLD.email,
            'annual_income', OLD.annual_income,
            'is_active',     OLD.is_active
        ),
        JSON_OBJECT(
            'email',         NEW.email,
            'annual_income', NEW.annual_income,
            'is_active',     NEW.is_active
        )
    );
END$$
 
CREATE TRIGGER trg_individual_after_delete
AFTER DELETE ON individual_taxpayers
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, action, record_id, changed_by, old_values, new_values)
    VALUES (
        'individual_taxpayers',
        'DELETE',
        OLD.taxpayer_id,
        USER(),
        JSON_OBJECT(
            'national_id', OLD.national_id,
            'first_name',  OLD.first_name,
            'last_name',   OLD.last_name,
            'email',       OLD.email
        ),
        NULL
    );
END$$
 
-- -------------------------------------------------------
-- TRIGGERS: corporate_taxpayers
-- -------------------------------------------------------
CREATE TRIGGER trg_corporate_after_insert
AFTER INSERT ON corporate_taxpayers
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, action, record_id, changed_by, old_values, new_values)
    VALUES (
        'corporate_taxpayers',
        'INSERT',
        NEW.corp_id,
        USER(),
        NULL,
        JSON_OBJECT(
            'registration_number', NEW.registration_number,
            'company_name',        NEW.company_name,
            'annual_revenue',      NEW.annual_revenue,
            'is_active',           NEW.is_active
        )
    );
END$$
 
CREATE TRIGGER trg_corporate_after_update
AFTER UPDATE ON corporate_taxpayers
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, action, record_id, changed_by, old_values, new_values)
    VALUES (
        'corporate_taxpayers',
        'UPDATE',
        NEW.corp_id,
        USER(),
        JSON_OBJECT(
            'company_name',   OLD.company_name,
            'annual_revenue', OLD.annual_revenue,
            'is_active',      OLD.is_active
        ),
        JSON_OBJECT(
            'company_name',   NEW.company_name,
            'annual_revenue', NEW.annual_revenue,
            'is_active',      NEW.is_active
        )
    );
END$$
 
-- -------------------------------------------------------
-- TRIGGERS: tax_assessments
-- -------------------------------------------------------
CREATE TRIGGER trg_assessment_after_insert
AFTER INSERT ON tax_assessments
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, action, record_id, changed_by, old_values, new_values)
    VALUES (
        'tax_assessments',
        'INSERT',
        NEW.assessment_id,
        USER(),
        NULL,
        JSON_OBJECT(
            'taxpayer_type',   NEW.taxpayer_type,
            'tax_year',        NEW.tax_year,
            'assessed_amount', NEW.assessed_amount,
            'status',          NEW.status,
            'due_date',        NEW.due_date
        )
    );
END$$
 
CREATE TRIGGER trg_assessment_after_update
AFTER UPDATE ON tax_assessments
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, action, record_id, changed_by, old_values, new_values)
    VALUES (
        'tax_assessments',
        'UPDATE',
        NEW.assessment_id,
        USER(),
        JSON_OBJECT(
            'assessed_amount', OLD.assessed_amount,
            'status',          OLD.status,
            'due_date',        OLD.due_date
        ),
        JSON_OBJECT(
            'assessed_amount', NEW.assessed_amount,
            'status',          NEW.status,
            'due_date',        NEW.due_date
        )
    );
END$$
 
-- -------------------------------------------------------
-- TRIGGERS: payments
-- -------------------------------------------------------
CREATE TRIGGER trg_payment_after_insert
AFTER INSERT ON payments
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, action, record_id, changed_by, old_values, new_values)
    VALUES (
        'payments',
        'INSERT',
        NEW.payment_id,
        USER(),
        NULL,
        JSON_OBJECT(
            'assessment_id',   NEW.assessment_id,
            'amount_paid',     NEW.amount_paid,
            'payment_method',  NEW.payment_method,
            'reference_number',NEW.reference_number
        )
    );
END$$
 
-- -------------------------------------------------------
-- TRIGGERS: penalties
-- -------------------------------------------------------
CREATE TRIGGER trg_penalty_after_insert
AFTER INSERT ON penalties
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, action, record_id, changed_by, old_values, new_values)
    VALUES (
        'penalties',
        'INSERT',
        NEW.penalty_id,
        USER(),
        NULL,
        JSON_OBJECT(
            'assessment_id',  NEW.assessment_id,
            'penalty_type',   NEW.penalty_type,
            'penalty_amount', NEW.penalty_amount,
            'waived',         NEW.waived
        )
    );
END$$
 
CREATE TRIGGER trg_penalty_after_update
AFTER UPDATE ON penalties
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, action, record_id, changed_by, old_values, new_values)
    VALUES (
        'penalties',
        'UPDATE',
        NEW.penalty_id,
        USER(),
        JSON_OBJECT(
            'waived',        OLD.waived,
            'waived_by',     OLD.waived_by,
            'waiver_reason', OLD.waiver_reason
        ),
        JSON_OBJECT(
            'waived',        NEW.waived,
            'waived_by',     NEW.waived_by,
            'waiver_reason', NEW.waiver_reason
        )
    );
END$$
 
DELIMITER ;
 
-- -------------------------------------------------------
-- VERIFY: after running the full script, this should
-- return 100+ rows across all monitored tables
-- -------------------------------------------------------
SELECT table_name, action, COUNT(*) AS event_count
  FROM audit_log
 GROUP BY table_name, action
 ORDER BY table_name, action;

-- -------------------------------------------------------
-- 5. TRANSACTIONS EXAMPLE
-- -------------------------------------------------------

-- Transaction: Pay assessment #4 and waive its penalty
START TRANSACTION;

    INSERT INTO payments (assessment_id, amount_paid, payment_method, reference_number, processed_by)
    VALUES (4, 8250.00, 'bank_transfer', 'REF-2024-TXN01', 2);

    UPDATE tax_assessments SET status = 'paid' WHERE assessment_id = 4;

    UPDATE penalties SET waived = 1, waived_by = 1, waiver_reason = 'First-time offender waiver'
    WHERE assessment_id = 4;

COMMIT;

-- -------------------------------------------------------
-- 6. QUERIES
-- -------------------------------------------------------

-- 6.1 CRUD OPERATIONS

-- SELECT: All active individual taxpayers with income > 100,000
SELECT taxpayer_id, CONCAT(first_name, ' ', last_name) AS full_name,
       national_id, annual_income, registration_date
  FROM individual_taxpayers
 WHERE is_active = 1 AND annual_income > 100000
 ORDER BY annual_income DESC;

-- INSERT: New individual taxpayer
-- (use stored procedure sp_register_individual in production)

-- UPDATE: Update corporate taxpayer annual revenue
UPDATE corporate_taxpayers
   SET annual_revenue = 14500000.00
 WHERE registration_number = 'CRP011';

-- DELETE: Soft-delete (deactivate) inactive taxpayer
UPDATE individual_taxpayers
   SET is_active = 0
 WHERE taxpayer_id = 20 AND annual_income < 30000;

-- 6.2 JOIN OPERATIONS

-- JOIN 1: Assessments with taxpayer names and category
SELECT
    ta.assessment_id,
    ta.tax_year,
    CASE ta.taxpayer_type
        WHEN 'individual' THEN CONCAT(it.first_name, ' ', it.last_name)
        ELSE ct.company_name
    END AS taxpayer_name,
    tc.category_name,
    ta.assessed_amount,
    ta.status,
    CONCAT(o.full_name) AS officer_name
FROM tax_assessments ta
LEFT JOIN individual_taxpayers it ON ta.individual_id = it.taxpayer_id
LEFT JOIN corporate_taxpayers  ct ON ta.corporate_id  = ct.corp_id
JOIN  tax_categories  tc ON ta.category_id  = tc.category_id
JOIN  tax_officers    o  ON ta.officer_id   = o.officer_id
ORDER BY ta.assessment_id;

-- JOIN 2: Payments with assessment and taxpayer info
SELECT
    p.payment_id,
    p.reference_number,
    p.payment_date,
    p.amount_paid,
    p.payment_method,
    CASE ta.taxpayer_type
        WHEN 'individual' THEN CONCAT(it.first_name, ' ', it.last_name)
        ELSE ct.company_name
    END AS taxpayer_name,
    ta.assessed_amount,
    o.full_name AS processed_by
FROM payments p
JOIN tax_assessments ta  ON p.assessment_id   = ta.assessment_id
LEFT JOIN individual_taxpayers it ON ta.individual_id = it.taxpayer_id
LEFT JOIN corporate_taxpayers  ct ON ta.corporate_id  = ct.corp_id
JOIN tax_officers o       ON p.processed_by   = o.officer_id
ORDER BY p.payment_date DESC;

-- 6.3 AGGREGATE FUNCTIONS

-- Total revenue collected per tax category
SELECT
    tc.category_name,
    COUNT(ta.assessment_id)     AS total_assessments,
    SUM(ta.assessed_amount)     AS total_assessed,
    SUM(p.amount_paid)          AS total_collected,
    AVG(ta.assessed_amount)     AS avg_assessment,
    ROUND(SUM(p.amount_paid) / SUM(ta.assessed_amount) * 100, 2) AS collection_rate_pct
FROM tax_categories tc
JOIN tax_assessments ta ON tc.category_id = ta.category_id
LEFT JOIN payments p    ON ta.assessment_id = p.assessment_id
GROUP BY tc.category_id, tc.category_name
ORDER BY total_collected DESC;

-- 6.4 SUBQUERY: Taxpayers with above-average assessed amounts
SELECT
    assessment_id,
    taxpayer_type,
    assessed_amount,
    status
FROM tax_assessments
WHERE assessed_amount > (
    SELECT AVG(assessed_amount)
    FROM tax_assessments
    WHERE status != 'cancelled'
)
ORDER BY assessed_amount DESC;

-- 6.5 COMPLEX QUERY: Revenue summary by taxpayer type and year
SELECT
    ta.taxpayer_type,
    ta.tax_year,
    COUNT(DISTINCT ta.assessment_id)    AS assessments_issued,
    SUM(ta.assessed_amount)             AS total_assessed,
    COALESCE(SUM(p.amount_paid), 0)     AS total_collected,
    SUM(COALESCE(pen.penalty_amount,0)) AS total_penalties,
    SUM(ta.assessed_amount)
        - COALESCE(SUM(p.amount_paid),0) AS outstanding_balance
FROM tax_assessments ta
LEFT JOIN payments  p   ON ta.assessment_id = p.assessment_id
LEFT JOIN penalties pen ON ta.assessment_id = pen.assessment_id
                        AND pen.waived = 0
GROUP BY ta.taxpayer_type, ta.tax_year
ORDER BY ta.tax_year, ta.taxpayer_type;

-- -------------------------------------------------------
-- 7. QUERY OPTIMIZATION ANALYSIS
-- -------------------------------------------------------

-- Verify indexes are used
EXPLAIN SELECT * FROM tax_assessments WHERE status = 'overdue';
EXPLAIN SELECT * FROM payments WHERE assessment_id = 11;
EXPLAIN SELECT * FROM individual_taxpayers WHERE national_id = 'NID005';

-- -------------------------------------------------------
-- 8. VIEW: OUTSTANDING BALANCE SUMMARY
-- -------------------------------------------------------
CREATE VIEW vw_outstanding_balances AS
SELECT
    ta.assessment_id,
    ta.tax_year,
    ta.taxpayer_type,
    CASE ta.taxpayer_type
        WHEN 'individual' THEN CONCAT(it.first_name, ' ', it.last_name)
        ELSE ct.company_name
    END AS taxpayer_name,
    tc.category_name,
    ta.assessed_amount,
    COALESCE(SUM(p.amount_paid), 0) AS total_paid,
    ta.assessed_amount - COALESCE(SUM(p.amount_paid), 0) AS balance_due,
    ta.due_date,
    ta.status
FROM tax_assessments ta
LEFT JOIN individual_taxpayers it ON ta.individual_id = it.taxpayer_id
LEFT JOIN corporate_taxpayers  ct ON ta.corporate_id  = ct.corp_id
JOIN  tax_categories tc ON ta.category_id = tc.category_id
LEFT JOIN payments p    ON ta.assessment_id = p.assessment_id
GROUP BY ta.assessment_id;

-- Query the view
SELECT * FROM vw_outstanding_balances WHERE status IN ('pending', 'overdue') ORDER BY balance_due DESC;

-- ============================================================
-- END OF SCRIPT
-- ============================================================

SELECT 'tax_categories' AS table_name, COUNT(*) AS rows_count FROM tax_categories
UNION ALL
SELECT 'individual_taxpayers', COUNT(*) FROM individual_taxpayers
UNION ALL
SELECT 'corporate_taxpayers', COUNT(*) FROM corporate_taxpayers
UNION ALL
SELECT 'tax_officers', COUNT(*) FROM tax_officers
UNION ALL
SELECT 'tax_assessments', COUNT(*) FROM tax_assessments
UNION ALL
SELECT 'payments', COUNT(*) FROM payments
UNION ALL
SELECT 'penalties', COUNT(*) FROM penalties
UNION ALL
SELECT 'audit_log', COUNT(*) FROM audit_log;
