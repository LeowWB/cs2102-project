create table Credit_cards
(
    number      varchar(20) primary key,
    cvv         varchar(10),
    expiry_date date
);

create table Customers
(
    cust_id integer primary key,
    address text,
    phone   varchar(20),
    name    text,
    email   text
);

create table Rooms
(
    rid              integer primary key,
    location         text,
    seating_capacity integer
);

create table Course_packages
(
    package_id             integer primary key,
    sale_start_date        date,
    sale_end_date          date,
    num_free_registrations integer,
    name                   text,
    price                  integer,

    check (sale_start_date < sale_end_date)
);

/*
 Employee.type and the subsequent foreign key constraints
 enforce the constraint that
 employees must be exactly one of
 full or part time.
 */

create table Employees
(
    eid         integer primary key,
    salary_type char(8)     not null
        check ( salary_type in ('full_time', 'part_time') ),
    job_type    varchar(10) not null
        check (job_type in ('administrator', 'manager', 'instructor')),
    name        text,
    phone       varchar(20),
    address     text,
    email       text,
    depart_date date,
    join_date   date,
    check (join_date < depart_date)
);

create table Part_time_Emp
(
    eid         integer primary key,
    hourly_rate float,
    type        char(8) not null default 'part_time'
        check ( type == 'part_time' ),
    foreign key (eid, type) references Employees (eid, salary_type)
);

create table Full_time_Emp
(
    eid            integer primary key,
    monthly_salary float,
    type           char(8) not null default 'full_time'
        check ( type == 'full_time' ),
    foreign key (eid, type) references Employees (eid, salary_type)
);

create table Instructors
(
    eid  integer references Employees (eid),
    type varchar(10) not null default 'instructor'
        check ( type == 'instructor' ),
    foreign key (eid, type) references Employees (eid, job_type)
);

create table Administrators
(
    eid  integer references Employees (eid),
    type varchar(10) not null default 'administrator'
        check ( type == 'administrator' ),
    foreign key (eid, type) references Employees (eid, job_type)
);

create table Managers
(
    eid  integer references Employees (eid),
    type varchar(10) not null default 'manager'
        check ( type == 'manager' ),
    foreign key (eid, type) references Employees (eid, job_type)
);

create table Course_areas
(
    name    text primary key,
    manager integer references Managers (eid)
);

create table Courses
(
    course_id   integer primary key,
    title       text,
    description text,
    duration    integer,
    area        integer references Course_areas (name)
);

create table Offerings
(
    course_id                   integer references Courses (course_id),
    launch_date                 date,
    fees                        float,
    target_number_registrations integer,
    registration_deadline       date,
    handler                     integer references Administrators (eid),
    -- seating capacity is derived from sessions
    -- check target_n_r < seating capacity
    -- start and end date is derived
    -- check end date - deadline >= 10
    primary key (course_id, launch_date)
);

create table Sessions
(
    sid         integer,
    course_id   integer,
    launch_date date,
    -- seating capacity is derived from room
    instructor  integer references Instructors (eid),
    day         varchar(10)
        check ( day in ('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday') ),
    hour        integer
        check (hour >= 9 and hour <= 18),
    room        integer references Rooms (rid),
    foreign key (course_id, launch_date) references Offerings (course_id, launch_date),
    primary key (sid, course_id, launch_date)
);