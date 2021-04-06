CALL add_customer('Jacinto Lind', '406 Turner Shores\nWest Sigridton, ME 20391', '90761391', 'jacinto.lind@example.com', '344671399807892', '2030-04-30', '5489');
CALL add_customer('Maryse Dach', '2980 Ebony Corner Apt. 859\nBellton, VA 99017-7381', '95010409', 'dach.maryse@example.net', '4024007179854135', '2023-08-08', '7717');
CALL add_customer('Molly Mop', '797 Jody Rest Apt. 324\nWest Augustine, MI 12631', '94021449', 'molly43@example.com', '4485612061643194', '2025-11-24', '4370');
CALL add_customer('Colleen Gibson', '8534 Maxime Keys\nSouth Bridie, OH 60303-9920', '99724688', 'gibson.colleen@example.com', '4532006442505973', '2023-04-11', '7654');
CALL add_customer('Vicky Gorczany', '2744 Fadel Pike Apt. 101\nMaximomouth, TX 74572', '95539476', 'gorczany.vicky@example.com', '4916091768888534', '2024-10-18', '8418');
CALL add_customer('Rhayes Corrin', '1709 Kemmer Creek Apt. 310\nBrendanchester, SD 90759-0836', '90701822', 'rhayes36@example.com', '4916424671016132', '2022-09-28', '5436');
CALL add_customer('Leila Torres', '265 Ulises Expressway\nRodriguezland, RI 59097', '97501506', 'leila72@example.org', '5180253314420403', '2022-08-06', '3491');
CALL add_customer('Venia Lou', '1938 Jean Inlet Apt. 402\nChadrickmouth, NJ 42426-0267', '92083106', 'louvenia82@example.org', '5279615931773372', '2023-08-11', '4973');
CALL add_customer('Tigre Enner', '413 Breitenberg Rapid Suite 403\nNew Hector, MO 08870', '96827965', 'savanah80@example.org', '5426004743132991', '2024-01-12', '2781');
CALL add_customer('Tavares Abbott', '836 Dariana Gateway\nLizafort, OK 11305', '90417928', 'abbott.tavares@example.org', '6011784365986811', '2026-11-13', '764');

INSERT INTO Rooms
VALUES (1, '92773 Millie Mission\nMarquardtstad, NY 77300-6093', 466),
       (2, '36964 Yost Burgs\nZboncakmouth, WA 85804-0810', 742),
       (3, '85028 Maggio Centers\nTadport, HI 96401', 496),
       (4, '55176 Bogan Roads\nEvalynland, NY 75571-2987', 824),
       (5, '549 Antonette Place\nBennymouth, AK 04005-0823', 90),
       (6, '56948 Doug Expressway\nSouth Ardithside, TN 47599-1211', 394),
       (7, '896 Chaz Ports Apt. 307\nNorth Victoria, ND 41615', 22),
       (8, '142 Christophe Roads Suite 611\nLake Alec, CT 85488', 338),
       (9, '267 Lesch Street\nPort Billborough, MN 36443-2798', 777),
       (10, '50170 Arjun Turnpike\nEmmettborough, IA 27098', 219);

CALL add_course_package('New Year Sale', 3, '2021-1-1', '2021-2-1', 5000);
CALL add_course_package('April Sale', 4, '2021-4-1', '2021-4-28', 10000);
CALL add_course_package('Bundle Sale', 8, '2021-1-2', '2021-5-1', 17000);
CALL add_course_package('Big Bundle', 15, '2021-1-3', '2021-12-1', 30000);
CALL add_course_package('Mid-Year Sale', 5, '2021-6-1', '2021-7-1', 11000);
CALL add_course_package('Value Package 1', 2, '2021-1-1', '2021-12-31', 3000);
CALL add_course_package('Value Package 2', 4, '2021-1-1', '2021-12-31', 6000);
CALL add_course_package('Value Package 3', 6, '2021-1-1', '2021-12-31', 9000);
CALL add_course_package('Value Package 4', 8, '2021-1-1', '2021-12-31', 12000);
CALL add_course_package('Value Package 5', 10, '2021-1-1', '2021-12-31', 15000);

INSERT INTO Buys
VALUES ('2021-01-14', 1, '344671399807892', 0),
       ('2021-01-28', 1, '4024007179854135', 3),
       ('2021-04-02', 2, '4485612061643194', 2),
       ('2021-01-13', 3, '4532006442505973', 7),
       ('2021-03-10', 3, '4916091768888534', 4),
       ('2021-01-03', 3, '4916424671016132', 0),
       ('2021-04-01', 4, '5180253314420403', 10),
       ('2000-03-05', 4, '5279615931773372', 1),
	   ('2021-03-01', 8, '5426004743132991', 6),
	   ('2021-03-01', 9, '6011784365986811', 8);

begin transaction; -- for employees
-- Instructors >= 1 course area, Managers >= 0, Admin = 0
-- Ensure every course area is being managed by 1 manager ONLY
-- Insert Managers first to insert Course Areas
CALL add_employee('Dayna Schultz', '877 Arlene Coves Suite 434\nNew Wilson, MN 88696-8280', '97303635', 'katelin.dietrich@example.org', 'full_time', 250000, '2019-11-11', 'manager', ARRAY[ 'math', 'programming', 'algorithms' ]);
CALL add_employee('Lorenz Walter V', '90722 Sienna Streets Suite 142\nWest Jerrod, DE 13419-1991', '95298596', 'fadel.hellen@example.org', 'full_time', 400000, '2011-11-06', 'manager', ARRAY[ 'databases', 'networks' ]);
CALL add_employee('Cletus Jerde', '775 Martina Station Apt. 190\nSouth Elody, IN 35993-2103', '97233481', 'haylie15@example.com', 'full_time', 225000, '2020-1-11', 'manager', ARRAY[]::text[]);
CALL add_employee('Madeline Parisian', '267 Kaylie Divide\nEstherstad, CA 46624-1390', '96836734', 'beverly20@example.org', 'part_time', 1200, '2015-08-22', 'instructor', ARRAY[ 'databases' ]);
CALL add_employee('Sally Wolowitz', '320 Wall Street\nRhodes Island, RI 341390', '90807762', 'wollosally@hotmail.com', 'part_time', 1300, '2017-10-7', 'instructor', ARRAY[ 'networks' ]);
CALL add_employee('Monserrate Kohler', '359 Jamir Square Apt. 048\nLake Zackery, NH 39502-1706', '96467215', 'blair.dach@example.org', 'full_time', 300000, '2003-04-30', 'instructor', ARRAY[ 'databases', 'math' ]);
CALL add_employee('Charlie Waltz', '23 Sentosa Cove Blk 10\nSingapore, S828696', '96215538', 'charlie.wz@google.com', 'full_time', 290000, '2016-3-21', 'administrator', ARRAY[]::text[]);
CALL add_employee('Andy Lou', '108 Serenity Walk\nNew York, NY, 38696-7921', '91031294', 'andlou80@yahoo.com', 'full_time', 310000, '2012-1-10', 'administrator', ARRAY[]::text[]);
CALL remove_employee(8, '2016-4-1');
CALL add_employee('Jerold D Dodd', '1341 Leverton Cove Road\nCalifornia, CA, 92391', '818-289-0907', 'jeroldd@gmail.com', 'full_time', 500000, '2021-01-01', 'instructor', ARRAY[ 'math', 'algorithms', 'programming', 'databases', 'networks' ]);
CALL add_employee('Rickey J Donaghy', '2069 Sherman Street\nKansas, KS, 66607', '785-806-3247', 'rickeyj@hotmail.com', 'full_time', 600000, '2021-01-01', 'instructor', ARRAY[ 'math', 'algorithms', 'programming', 'databases', 'networks' ]);

commit; -- for employees

CALL add_course('CS2102', 'Database Systems', 'databases', 2);
CALL add_course('MA1101R', 'Linear Algebra I', 'math', 2);
CALL add_course('CS2105', 'Introduction to Computer Networks', 'networks', 1);
CALL add_course('MA1521', 'Calculus for Computing', 'math', 1);
CALL add_course('CS1010', 'Programming Methodology I', 'programming', 2);
CALL add_course('CS2030', 'Programming Methodology II', 'programming', 2);
CALL add_course('CS2040', 'Data Structures and Algorithms', 'algorithms', 3);
CALL add_course('CS3230', 'Design and Analysis of Algorithms', 'algorithms', 3);
CALL add_course('CS4224', 'Distributed Databases', 'databases', 4);
CALL add_course('CS5229', 'Advanced Computer Networks', 'networks', 4);

BEGIN TRANSACTION; -- for offerings
-- Try to get offerings that have past, ongoing, and available soon
CALL add_course_offering(1, 1, 30000, 1000, '2020-1-1', '2020-4-1', 7, ARRAY[ ('2020-5-4', 9, 1), ('2020-5-4', 14, 2) ]::session_info[]);
CALL add_course_offering(2, 1, 30000, 800, '2021-4-1', '2021-6-1', 7, ARRAY[ ('2021-7-5', 14, 1), ('2021-7-5', 16, 1) ]::session_info[]);
CALL add_course_offering(3, 2, 25000, 700, '2021-2-1', '2021-6-1', 7, ARRAY[ ('2021-7-2', 10, 3), ('2021-7-6', 10, 3) ]::session_info[]);
CALL add_course_offering(4, 3, 40000, 500, '2021-6-1', '2021-8-1', 7, ARRAY[ ('2021-9-6', 15, 4), ('2021-9-7', 9, 4) ]::session_info[]);
CALL add_course_offering(5, 5, 5000, 100, '2021-4-1', '2021-6-1', 7, ARRAY[ ('2021-6-11', 9, 5), ('2021-6-11', 10, 6) ]::session_info[]);
CALL add_course_offering(6, 6, 6000, 200, '2021-4-1', '2021-6-1', 7, ARRAY[ ('2021-6-14', 10, 6), ('2021-6-15', 16, 7) ]::session_info[]);
CALL add_course_offering(7, 7, 7000, 300, '2021-4-1', '2021-6-1', 7, ARRAY[ ('2021-6-16', 9, 7), ('2021-6-16', 15, 8) ]::session_info[]);
CALL add_course_offering(8, 8, 8000, 400, '2021-4-1', '2021-6-1', 7, ARRAY[ ('2021-6-16', 14, 9), ('2021-6-17', 15, 9) ]::session_info[]);
CALL add_course_offering(9, 9, 9000, 500, '2021-4-1', '2021-6-1', 7, ARRAY[ ('2021-6-18', 14, 9), ('2021-6-21', 14, 10) ]::session_info[]);
CALL add_course_offering(10, 10, 10000, 600, '2021-4-1', '2021-6-1', 7, ARRAY[ ('2021-6-21', 14, 2), ('2021-6-22', 14, 3) ]::session_info[]);

COMMIT; -- for offerings

CALL register_session(1, 2, 1, 'credit_card');
CALL register_session(2, 3, 1, 'credit_card');
CALL register_session(3, 3, 1, 'credit_card');
CALL register_session(4, 5, 1, 'credit_card');
CALL register_session(6, 6, 1, 'credit_card');
CALL register_session(5, 7, 1, 'course_package');
CALL register_session(7, 8, 1, 'course_package');
CALL register_session(8, 9, 1, 'course_package');
CALL register_session(9, 10, 1, 'course_package');
CALL register_session(10, 2, 1, 'course_package');
CALL cancel_registration(1, 2);
CALL cancel_registration(2, 3);
CALL cancel_registration(3, 3);
CALL cancel_registration(4, 5);
CALL cancel_registration(6, 6);
CALL cancel_registration(5, 7);
CALL cancel_registration(7, 8);
CALL cancel_registration(8, 9);
CALL cancel_registration(9, 10);
CALL cancel_registration(10, 2);
CALL register_session(1, 2, 1, 'credit_card');
CALL register_session(1, 3, 1, 'credit_card');
CALL register_session(2, 3, 1, 'credit_card');
CALL register_session(2, 5, 1, 'credit_card');
CALL register_session(3, 3, 1, 'credit_card');
CALL register_session(3, 5, 1, 'credit_card');
CALL register_session(8, 5, 1, 'credit_card');
CALL register_session(8, 6, 1, 'credit_card');
CALL register_session(6, 6, 1, 'credit_card');
CALL register_session(6, 7, 1, 'credit_card');
CALL register_session(5, 7, 1, 'course_package');
CALL register_session(5, 8, 1, 'course_package');
CALL register_session(7, 8, 1, 'course_package');
CALL register_session(7, 9, 1, 'course_package');
CALL register_session(4, 9, 1, 'course_package');
CALL register_session(4, 10, 1, 'course_package');
CALL register_session(9, 10, 1, 'course_package');
CALL register_session(9, 2, 1, 'course_package');
CALL register_session(10, 2, 1, 'course_package');
CALL register_session(10, 3, 1, 'course_package');

INSERT INTO Pay_slips
VALUES ('2021-02-28', 250000, 0, 28, 1),
       ('2021-02-28', 400000, 0, 28, 2),
       ('2021-02-28', 225000, 0, 28, 3),
       ('2021-02-28', 108000, 90, 0, 4),
       ('2021-02-28', 136500, 105, 0, 5),
       ('2021-02-28', 290000, 0, 28, 6),
       ('2021-02-28', 310000, 0, 28, 7),
       ('2021-02-28', 500000, 0, 28, 9),
       ('2021-02-28', 600000, 0, 28, 10),
       ('2021-03-31', 250000, 0, 31, 1),
       ('2021-03-31', 400000, 0, 31, 2),
       ('2021-03-31', 225000, 0, 31, 3),
       ('2021-03-31', 132000, 110, 0, 4),
       ('2021-03-31', 156000, 120, 0, 5),
       ('2021-03-31', 290000, 0, 31, 6),
       ('2021-03-31', 310000, 0, 31, 7),
       ('2021-03-31', 500000, 0, 31, 9),
       ('2021-03-31', 600000, 0, 31, 10);