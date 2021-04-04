CALL add_customer('Jacinto Lind', '406 Turner Shores\nWest Sigridton, ME 20391', '90761391', 'jacinto.lind@example.com', '344671399807892', '2030-04-30', '5489');
CALL add_customer('Maryse Dach', '2980 Ebony Corner Apt. 859\nBellton, VA 99017-7381', '95010409', 'dach.maryse@example.net', '4024007179854135', '2023-08-08', '7717');
CALL add_customer('Molly Mop', '797 Jody Rest Apt. 324\nWest Augustine, MI 12631', '94021449', 'molly43@example.com', '4485612061643194', '2025-11-24', '4370');
CALL add_customer('Colleen Gibson', '8534 Maxime Keys\nSouth Bridie, OH 60303-9920', '99724688', 'gibson.colleen@example.com', '4532006442505973', '2023-04-11', '7654');
CALL add_customer('Vicky Gorczany', '2744 Fadel Pike Apt. 101\nMaximomouth, TX 74572', '95539476', 'gorczany.vicky@example.com', '4916091768888534', '2015-10-18', '8418');
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

INSERT INTO Buys
VALUES ('2021-01-14', 1, '344671399807892', 0),
       ('2021-01-28', 1, '4024007179854135', 3),
       ('2021-04-02', 2, '4485612061643194', 2),
       ('2021-01-13', 3, '4532006442505973', 7),
       ('2021-03-10', 3, '4916091768888534', 4),
       ('2021-01-03', 3, '4916424671016132', 0),
       ('2021-04-01', 4, '5180253314420403', 10),
       ('2000-03-05', 4, '5279615931773372', 1);

begin transaction; -- for employees
-- Instructors >= 1 course area, Managers >= 0, Admin = 0
-- Ensure every course area is being managed by 1 manager ONLY
CALL add_employee('Madeline Parisian', '267 Kaylie Divide\nEstherstad, CA 46624-1390', '96836734', 'beverly20@example.org', 'part_time', 1200, '2015-08-22', 'instructor', ARRAY[ 'databases' ]);
CALL add_employee('Sally Wolowitz', '320 Wall Street\nRhodes Island, RI 341390', '90807762', 'wollosally@hotmail.com', 'part_time', 1300, '2017-10-7', 'instructor', ARRAY[ 'networks' ]);
CALL add_employee('Mr. Monserrate Kohler', '359 Jamir Square Apt. 048\nLake Zackery, NH 39502-1706', '96467215', 'blair.dach@example.org', 'full_time', 300000, '2003-04-30', 'instructor', ARRAY[ 'databases', 'math' ]);
CALL add_employee('Dayna Schultz', '877 Arlene Coves Suite 434\nNew Wilson, MN 88696-8280', '97303635', 'katelin.dietrich@example.org', 'full_time', 250000, '2019-11-11', 'manager', ARRAY[ 'math' ]);
CALL add_employee('Prof. Lorenz Walter V', '90722 Sienna Streets Suite 142\nWest Jerrod, DE 13419-1991', '95298596', 'fadel.hellen@example.org', 'full_time', 400000, '2011-11-06', 'manager', ARRAY[ 'databases', 'networks' ]);
CALL add_employee('Cletus Jerde', '775 Martina Station Apt. 190\nSouth Elody, IN 35993-2103', '97233481', 'haylie15@example.com', 'full_time', 225000, '2020-1-11', 'manager', ARRAY[ ]);
CALL add_employee('Charlie Waltz', '23 Sentosa Cove Blk 10\nSingapore, S828696', '96215538', 'charlie.wz@google.com', 'full_time', 290000, '2016-3-21', 'administrator', ARRAY[ ]);
CALL add_employee('Andy Lou', '108 Serenity Walk\nNew York, NY, 38696-7921', '91031294', 'andlou80@yahoo.com', 'full_time', 310000, '2012-1-10', 'administrator', ARRAY[ ]);
CALL remove_employee(8, '2016-4-1');

commit; -- for employees

CALL add_course('CS2102', 'Fundamentals of databases', 'databases', 2);
CALL add_course('MA1101R', 'Linear Algebra', 'math', 2);
CALL add_course('CS2105', 'Computer Networks', 'networks', 1);

BEGIN TRANSACTION; -- for offerings
-- Try to get offerings that have past, ongoing, and available soon
CALL add_course_offering(1, 1, 30000, 1000, '2021-1-1', '2020-4-1', 7, ARRAY[ (date'2021-1-4', 9, 1)::session_info, (date'2021-1-4', 2, 2)::session_info ]);
CALL add_course_offering(2, 1, 30000, 800, '2021-4-1', '2020-6-1', 7, ARRAY[ (date'2021-4-5', 3, 1)::session_info, (date'2021-4-5', 2, 1)::session_info ]);
CALL add_course_offering(3, 2, 25000, 700, '2021-2-1', '2020-6-1', 7, ARRAY[ (date'2021-3-2', 10, 3)::session_info, (date'2021-3-3', 10, 3)::session_info ]);
CALL add_course_offering(4, 3, 40000, 500, '2021-6-1', '2020-8-1', 7, ARRAY[ (date'2021-4-5', 3, 4)::session_info, (date'2021-4-6', 9, 4)::session_info ]);

COMMIT; -- for offerings

