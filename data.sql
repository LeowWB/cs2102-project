INSERT INTO Customers
VALUES (1, '406 Turner Shores\nWest Sigridton, ME 20391', '90761391', 'omnis', 'jacinto.lind@example.com'),
       (2, '2980 Ebony Corner Apt. 859\nBellton, VA 99017-7381', '95010409', 'quam', 'dach.maryse@example.net'),
       (3, '797 Jody Rest Apt. 324\nWest Augustine, MI 12631', '94021449', 'aperiam', 'molly43@example.com'),
       (4, '8534 Maxime Keys\nSouth Bridie, OH 60303-9920', '99724688', 'maxime', 'gibson.colleen@example.com'),
       (5, '2744 Fadel Pike Apt. 101\nMaximomouth, TX 74572', '95539476', 'eum', 'gorczany.vicky@example.com'),
       (6, '1709 Kemmer Creek Apt. 310\nBrendanchester, SD 90759-0836', '90701822', 'quibusdam', 'rhayes@example.net'),
       (7, '265 Ulises Expressway\nRodriguezland, RI 59097', '97501506', 'suscipit', 'leila72@example.org'),
       (8, '1938 Jean Inlet Apt. 402\nChadrickmouth, NJ 42426-0267', '92083106', 'voluptas', 'louvenia82@example.org'),
       (9, '413 Breitenberg Rapid Suite 403\nNew Hector, MO 08870', '96827965', 'nemo', 'savanah80@example.org'),
       (10, '836 Dariana Gateway\nLizafort, OK 11305', '90417928', 'quae', 'abbott.tavares@example.org');

INSERT INTO Credit_cards
VALUES ('344671399807892', '5489', 4, '2004-03-15 10:09:32', '2030-04-30'),
       ('4024007179854135', '7717', 10, '1978-09-10 04:23:17', '2023-08-08'),
       ('4485612061643194', '4370', 7, '1989-04-18 12:06:58', '2025-11-24'),
       ('4532006442505973', '7654', 8, '1990-02-07 10:46:04', '2023-04-11'),
       ('4916091768888534', '8418', 1, '1977-10-24 15:35:56', '2015-10-18'),
       ('4916424671016132', '5436', 6, '2000-04-04 23:33:25', '2022-09-28'),
       ('5180253314420403', '3491', 2, '1977-04-05 11:14:30', '2022-08-06'),
       ('5279615931773372', '4973', 3, '1973-08-15 02:36:01', '2023-08-11'),
       ('5426004743132991', '2781', 5, '2015-06-21 11:16:25', '2024-01-12'),
       ('6011784365986811', '764', 9, '2007-09-24 02:21:47', '2026-11-13');

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

INSERT INTO Course_packages
VALUES (1, '1980-03-01', '1982-10-11', 20, 'aliquid', 48727),
       (2, '2002-04-22', '2002-08-28', 19, 'autem', 62670),
       (3, '2017-08-14', '2018-04-08', 12, 'ratione', 88280),
       (4, '1972-09-05', '2003-06-06', 11, 'molestias', 25709),
       (5, '1969-09-05', '1970-03-08', 14, 'iste', 45381),
       (6, '1986-04-12', '2010-12-02', 8, 'sed', 80933),
       (7, '1969-03-01', '1970-08-20', 8, 'suscipit', 11984),
       (8, '1977-01-01', '1977-06-22', 8, 'quo', 72244),
       (9, '2001-06-16', '2002-02-12', 8, 'architecto', 33887),
       (10, '1988-09-11', '2014-08-19', 8, 'debitis', 69137);

INSERT INTO Buys
VALUES ('2002-09-14', 1, '344671399807892', 0),
       ('1972-06-30', 2, '4024007179854135', 7),
       ('1974-05-19', 3, '4485612061643194', 11),
       ('1982-10-22', 4, '4532006442505973', 7),
       ('1992-05-19', 5, '4916091768888534', 20),
       ('1999-01-01', 6, '4916424671016132', 0),
       ('1995-09-24', 7, '5180253314420403', 6),
       ('2000-02-05', 8, '5279615931773372', 2),
       ('1980-04-29', 9, '5426004743132991', 11),
       ('1990-10-10', 10, '6011784365986811', 4);

begin transaction; -- for employees
INSERT INTO Employees
VALUES (1, 'part_time', 'part_time_instructor', 'Madeline Parisian', '96836734',
        '267 Kaylie Divide\nEstherstad, CA 46624-1390', 'beverly20@example.org', '2020-10-29', '2015-08-22'),
       (2, 'full_time', 'administrator', 'Mr. Monserrate Kohler', '96467215',
        '359 Jamir Square Apt. 048\nLake Zackery, NH 39502-1706', 'blair.dach@example.org', '2020-10-27', '2003-04-30'),
       (3, 'full_time', 'manager', 'Dayna Schultz', '97303635', '877 Arlene Coves Suite 434\nNew Wilson, MN 88696-8280',
        'katelin.dietrich@example.org', '2020-12-16', '2019-11-11'),
       (4, 'full_time', 'manager', 'Prof. Lorenz Walter V', '95298596',
        '90722 Sienna Streets Suite 142\nWest Jerrod, DE 13419-1991', 'fadel.hellen@example.org', '2020-07-30',
        '2011-11-06'),
       (5, 'full_time', 'full_time_instructor', 'Cletus Jerde', '97233481',
        '775 Martina Station Apt. 190\nSouth Elody, IN 35993-2103', 'haylie15@example.com', '2020-05-31', '1983-09-03');

INSERT INTO Part_time_Emp
VALUES (1, 1450, 'part_time');

INSERT INTO Full_time_Emp
VALUES (2, 145000, 'full_time'),
       (3, 145000, 'full_time'),
       (4, 145000, 'full_time'),
       (5, 145000, 'full_time');

INSERT INTO Managers VALUES
(3, 'manager'),
(4, 'manager');

INSERT INTO Administrators VALUES
(2, 'administrator');

insert into Instructors VALUES
(1, 'part_time_instructor'),
(5, 'full_time_instructor');

commit; -- for employees

insert into Course_areas VALUES
('math', 3);

INSERT INTO Courses VALUES
(1, 'CS2102', 'db', 2, 'math');

INSERT INTO Specializes VALUES
(5, 'math');

BEGIN TRANSACTION; -- for offerings
INSERT INTO Offerings VALUES
(1, 1, '2020-05-31', 10000, 20, '2020-05-11', 2);

INSERT INTO Sessions VALUES
(1, 1, 5, '2020-06-01', 9, 5 );
COMMIT; -- for offerings

