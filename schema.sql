-- all monetary values are stored as int (number of cents) to avoid recurring decimals
create table Customers
(
    cust_id serial primary key,
    address text,
    phone   varchar(20),
    name    text,
    email   text
);

-- some credit cards have 19-digit numbers
create table Credit_cards
(
    number      varchar(19) primary key,
    cvv         varchar(4),
    cust_id     integer,
    from_date   date,
    expiry_date date,
    check (expiry_date > from_date),
    foreign key (cust_id) references Customers (cust_id)
);

create table Rooms
(
    rid              serial primary key,
    location         text,
    seating_capacity integer
);

create table Course_packages
(
    package_id             serial primary key,
    sale_start_date        date,
    sale_end_date          date,
    num_free_registrations integer,
    name                   text,
    price                  integer,

    check (sale_start_date < sale_end_date)
);

-- no need cust_id; if we know the credit card number then we know the customer
create table Buys
(
    date                      date,
    package_id                integer references Course_packages (package_id),
    number                    varchar(19) references Credit_cards (number),
    num_remaining_redemptions integer,
    primary key (date, package_id, number)
);

/*
 Employee.type and the subsequent foreign key constraints
 enforce the constraint that
 employees must be exactly one of
 full or part time.
 */

create table Employees
(
    eid         serial primary key,
    salary_type char(9)     not null
        check ( salary_type in ('full_time', 'part_time') ),
    job_type    varchar(20) not null
        check (job_type in ('administrator', 'manager', 'full_time_instructor', 'part_time_instructor')),
    name        text,
    phone       varchar(20),
    address     text,
    email       text,
    depart_date date,
    join_date   date,
    check (join_date < depart_date),
    unique (eid, job_type),
    unique (eid, salary_type)
);

create table Part_time_Emp
(
    eid         integer primary key,
    hourly_rate int,
    salary_type char(9) not null default 'part_time'
        check ( salary_type = 'part_time' ),
    foreign key (eid, salary_type) references Employees (eid, salary_type) on delete cascade
);

create table Full_time_Emp
(
    eid            integer primary key,
    monthly_salary int,
    salary_type    char(9) not null default 'full_time'
        check ( salary_type = 'full_time' ),
    foreign key (eid, salary_type) references Employees (eid, salary_type) on delete cascade
);

create table Instructors
(
    eid      integer,
    job_type varchar(20) not null,
    check ( job_type in ('full_time_instructor', 'part_time_instructor')),
    primary key (eid),
    foreign key (eid, job_type) references Employees (eid, job_type) on delete cascade,
    unique (eid, job_type)
);

create table Administrators
(
    eid      integer references Full_time_Emp (eid) primary key,
    job_type varchar(20) not null default 'administrator'
        check ( job_type = 'administrator' ),
    foreign key (eid, job_type) references Employees (eid, job_type) on delete cascade
);

create table Managers
(
    eid      integer references Full_time_Emp (eid) primary key,
    job_type varchar(20) not null default 'manager'
        check ( job_type = 'manager' ),
    foreign key (eid, job_type) references Employees (eid, job_type) on delete cascade
);

create table Part_time_instructors
(
    eid      integer references Part_time_Emp (eid) primary key,
    job_type varchar(20) not null default 'part_time_instructor'
        check ( job_type = 'part_time_instructor' ),
    foreign key (eid, job_type) references Instructors (eid, job_type) on delete cascade
);

create table Full_time_instructors
(
    eid      integer references Full_time_Emp (eid) primary key,
    job_type varchar(20) not null default 'full_time_instructor'
        check ( job_type = 'full_time_instructor' ),
    foreign key (eid, job_type) references Instructors (eid, job_type) on delete cascade
);

create table Course_areas
(
    name    text primary key,
    manager integer references Managers (eid)
);

create table Specializes
(
    eid  integer references Instructors (eid),
    name text references Course_areas (name),
    primary key (eid, name)
);

create table Courses
(
    course_id   serial primary key,
    title       text unique,
    description text,
    duration    integer,
    area        text references Course_areas (name)
);

create table Offerings
(
    course_id                   integer references Courses (course_id),
    launch_date                 date,
    fees                        int,
    target_number_registrations integer,
    registration_deadline       date,
    handler                     integer references Administrators (eid) not null,
    -- seating capacity is derived from sessions
    -- check target_n_r < seating capacity
    -- start and end date is derived
    -- check end date - deadline >= 10
    primary key (course_id, launch_date)
);

-- assume all sessions last exactly one hour.
-- rationale: when we create a new session, we do not need to specify duration or end time (see
-- functionality 24 in the specs). therefore we assume duration is constant.
create table Sessions
(
    sid         integer,
    course_id   integer,
    launch_date date,
    -- seating capacity is derived from room
    instructor  integer references Instructors (eid) not null,
    date        date,
    start_time  integer
        check ((start_time >= 9 and start_time < 12) or (start_time >= 14 and start_time < 18)),
    room        integer references Rooms (rid) not null,
    foreign key (course_id, launch_date) references Offerings (course_id, launch_date),
    unique (course_id, launch_date, date, start_time),
    primary key (sid, course_id, launch_date)
);


create table Registers
(
    date        date,
    number      varchar(19),
    sid         integer,
    course_id   integer,
    launch_date date,
    primary key (date, number, sid, course_id, launch_date),
    foreign key (number) references Credit_cards (number),
    foreign key (sid, course_id, launch_date) references Sessions (sid, course_id, launch_date)
);

create table Redeems
(
    buys_date   date,
    package_id  integer,
    number      varchar(19),
    date        date,
    sid         integer,
    course_id   integer,
    launch_date date,
    primary key (buys_date, package_id, number, date, sid, course_id, launch_date),
    foreign key (buys_date, package_id, number) references Buys (date, package_id, number),
    foreign key (sid, course_id, launch_date) references Sessions (sid, course_id, launch_date)
);

create table Cancels
(
    cust_id        integer,
    date           date,
    sid            integer,
    launch_date    date,
    course_id      integer,
    refund_amt     integer,
    package_credit integer,
    primary key (cust_id, date, sid, launch_date, course_id),
    foreign key (cust_id) references Customers (cust_id),
    foreign key (sid, launch_date, course_id) references Sessions (sid, launch_date, course_id)
);

create table Pay_slips
(
    payment_date   date,
    amount         integer, --store in cents
    num_work_hours integer,
    num_work_days  integer,
    eid            integer,
    primary key (payment_date, eid),
    foreign key (eid) references Employees (eid),
    check ((amount >= 0) and (num_work_hours >= 0) and (num_work_days >= 0))
);


-- TRIGGERS ----------------------------------------------------------------------------------------

-- Each course offering consists of one or more sessions

create constraint trigger each_offering_at_least_one_session_t1
before insert on Offerings
deferrable initially deferred
for each row execute function each_offering_at_least_one_session_f1();

create trigger each_offering_at_least_one_session_t2
before delete on Sessions
deferrable initially deferred
for each row execute function each_offering_at_least_one_session_f2();

create or replace function each_offering_at_least_one_session_f1()
returns trigger as $$
    declare
        num_sessions integer;
    begin
        select count(*) into num_sessions 
        from Sessions
        where course_id = NEW.course_id and launch_date = NEW.launch_date;
        if count = 0 then
            raise notice 'Each course offering consists of one or more sessions';
            return null;
        end if;
    end;
$$ language plpgsql;

create or replace function each_offering_at_least_one_session_f2()
returns trigger as $$
    declare
        num_sessions integer;
    begin
        select count(*) into num_sessions 
        from Sessions
        where course_id = OLD.course_id and launch_date = OLD.launch_date;
        if count <= 1 then
            raise notice 'Each course offering consists of one or more sessions';
            return null;
        end if;
    end;
$$ language plpgsql;
