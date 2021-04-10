-- all monetary values are stored as int (number of cents) to avoid recurring decimals
drop table if exists Customers cascade;
create table Customers
(
    cust_id serial primary key,
    address text,
    phone   varchar(20),
    name    text not null,
    email   text
);

-- some credit cards have 19-digit numbers
drop table if exists Credit_cards cascade;
create table Credit_cards
(
    number      varchar(19) primary key,
    cvv         varchar(4) not null,
    cust_id     integer not null,
    from_date   timestamp not null,
    expiry_date date not null,
    check (expiry_date > from_date),
    foreign key (cust_id) references Customers (cust_id)
);

drop table if exists Rooms cascade;
create table Rooms
(
    rid              serial primary key,
    location         text not null,
    seating_capacity integer not null
);

drop table if exists Course_packages cascade;
create table Course_packages
(
    package_id             serial primary key,
    sale_start_date        date not null,
    sale_end_date          date not null,
    num_free_registrations integer not null
        check (num_free_registrations > 0),
    name                   text not null,
    price                  integer not null
        check (price > 0),

    check (sale_start_date < sale_end_date)
);

-- no need cust_id; if we know the credit card number then we know the customer
drop table if exists Buys cascade;
create table Buys
(
    date                      timestamp not null,
    package_id                integer references Course_packages (package_id),
    number                    varchar(19) references Credit_cards (number),
    num_remaining_redemptions integer not null,
    primary key (date, package_id, number)
);

/*
 Employee.type and the subsequent foreign key constraints
 enforce the constraint that
 employees must be exactly one of
 full or part time.
 */

drop table if exists Employees cascade;
create table Employees
(
    eid         serial primary key,
    salary_type char(9)     not null
        check ( salary_type in ('full_time', 'part_time') ),
    job_type    varchar(20) not null
        check (job_type in ('administrator', 'manager', 'full_time_instructor', 'part_time_instructor')),
    name        text not null,
    phone       varchar(20),
    address     text,
    email       text,
    depart_date date,
    join_date   date not null,
    check (join_date < depart_date),
    unique (eid, job_type),
    unique (eid, salary_type)
);

drop table if exists Part_time_Emp cascade;
create table Part_time_Emp
(
    eid         integer primary key,
    hourly_rate int not null,
    salary_type char(9) not null default 'part_time'
        check ( salary_type = 'part_time' ),
    foreign key (eid, salary_type) references Employees (eid, salary_type) on delete cascade
);

drop table if exists Full_time_Emp cascade;
create table Full_time_Emp
(
    eid            integer primary key,
    monthly_salary int not null,
    salary_type    char(9) not null default 'full_time'
        check ( salary_type = 'full_time' ),
    foreign key (eid, salary_type) references Employees (eid, salary_type) on delete cascade
);

drop table if exists Instructors cascade;
create table Instructors
(
    eid      integer,
    job_type varchar(20) not null,
    check ( job_type in ('full_time_instructor', 'part_time_instructor')),
    primary key (eid),
    foreign key (eid, job_type) references Employees (eid, job_type) on delete cascade,
    unique (eid, job_type)
);

drop table if exists Administrators cascade;
create table Administrators
(
    eid      integer references Full_time_Emp (eid) primary key,
    job_type varchar(20) not null default 'administrator'
        check ( job_type = 'administrator' ),
    foreign key (eid, job_type) references Employees (eid, job_type) on delete cascade
);

drop table if exists Managers cascade;
create table Managers
(
    eid      integer references Full_time_Emp (eid) primary key,
    job_type varchar(20) not null default 'manager'
        check ( job_type = 'manager' ),
    foreign key (eid, job_type) references Employees (eid, job_type) on delete cascade
);

-- probably not needed?
/*
drop table if exists Part_time_instructors cascade;
create table Part_time_instructors
(
    eid      integer references Part_time_Emp (eid) primary key,
    job_type varchar(20) not null default 'part_time_instructor'
        check ( job_type = 'part_time_instructor' ),
    foreign key (eid, job_type) references Instructors (eid, job_type) on delete cascade
);

drop table if exists Full_time_instructors cascade;
create table Full_time_instructors
(
    eid      integer references Full_time_Emp (eid) primary key,
    job_type varchar(20) not null default 'full_time_instructor'
        check ( job_type = 'full_time_instructor' ),
    foreign key (eid, job_type) references Instructors (eid, job_type) on delete cascade
);
*/

drop table if exists Course_areas cascade;
create table Course_areas
(
    name    text primary key,
    manager integer not null references Managers (eid)
);

drop table if exists Specializes cascade;
create table Specializes
(
    eid  integer references Instructors (eid),
    name text not null references Course_areas (name),
    primary key (eid, name)
);

drop table if exists Courses cascade;
create table Courses
(
    course_id   serial primary key,
    title       text not null unique,
    description text not null,
    duration    integer not null,
    area        text not null references Course_areas (name)
);

drop table if exists Offerings cascade;
create table Offerings
(
    offering_id	                integer primary key,
    course_id                   integer not null references Courses (course_id),
    launch_date                 date not null,
    fees                        integer not null
        check ( fees >= 0 ),
    target_number_registrations integer not null
        check ( target_number_registrations >= 0 ),
    registration_deadline       date not null,
    handler                     integer references Administrators (eid) not null,
    -- seating capacity is derived from sessions
    -- check target_n_r < seating capacity
    -- start and end date is derived
    -- check end date - deadline >= 10
    unique (course_id, launch_date)
);

-- assume all sessions last exactly one hour.
-- rationale: when we create a new session, we do not need to specify duration or end time (see
-- functionality 24 in the specs). therefore we assume duration is constant.
drop table if exists Sessions cascade;
create table Sessions
(
    sid         integer,
    offering_id integer references Offerings (offering_id) not null,
    -- seating capacity is derived from room
    instructor  integer references Instructors (eid) not null,
    date        date not null,
    start_time  integer not null
        check ((start_time >= 9 and start_time < 12) or (start_time >= 14 and start_time < 18)),
    room        integer references Rooms (rid) not null,
    unique (offering_id, date, start_time),
    primary key (sid, offering_id)
);

drop table if exists Registers cascade;
create table Registers
(
    date        timestamp,
    number      varchar(19),
    sid         integer,
    offering_id integer,
    primary key (date, number, sid, offering_id),
    foreign key (number) references Credit_cards (number),
    foreign key (sid, offering_id) references Sessions (sid, offering_id)
		on delete cascade
);

drop table if exists Redeems cascade;
create table Redeems
(
    buys_date   timestamp,
    package_id  integer,
    number      varchar(19),
    date        timestamp,
    sid         integer,
    offering_id integer references Offerings (offering_id) not null,
    primary key (buys_date, package_id, number, date, sid, offering_id),
    foreign key (buys_date, package_id, number) references Buys (date, package_id, number),
    foreign key (sid, offering_id) references Sessions (sid, offering_id)
		on delete cascade
);

drop table if exists Cancels cascade;
create table Cancels
(
    cust_id        integer,
    date           timestamp,
    sid            integer,
    offering_id integer references Offerings (offering_id) not null,
    refund_amt     integer,
    package_credit integer,
    primary key (cust_id, date, sid, offering_id),
    foreign key (cust_id) references Customers (cust_id),
    foreign key (sid, offering_id) references Sessions (sid, offering_id)
		on delete cascade
);

drop table if exists Pay_slips cascade;
create table Pay_slips
(
    payment_date   date,
    amount         integer not null, --store in cents
    num_work_hours integer,
    num_work_days  integer,
    eid            integer,
    primary key (payment_date, eid),
    foreign key (eid) references Employees (eid),
    check ((amount >= 0) and (num_work_hours >= 0) and (num_work_days >= 0))
);


-- TRIGGERS ----------------------------------------------------------------------------------------

-- Each course offering consists of one or more sessions

create or replace function each_offering_at_least_one_session_f()
returns trigger as $$
    declare
        num_sessions integer;
        changed_offering_id integer;
    begin
        if (tg_op = 'INSERT') then
            -- insert into offerings
            changed_offering_id := NEW.offering_id;
        else
            -- delete from sessions
            changed_offering_id := OLD.offering_id;
        end if;
        select count(*) into num_sessions
        from Sessions
        where offering_id = changed_offering_id;
        if num_sessions = 0 then
            raise 'Each course offering consists of one or more sessions';
        end if;
        if (tg_op = 'INSERT') then
            return null;
        else
            return OLD;
        end if;
    end;
$$ language plpgsql;

drop trigger if exists each_offering_at_least_one_session_t1 on Offerings;
create constraint trigger each_offering_at_least_one_session_t1
after insert on Offerings
DEFERRABLE INITIALLY DEFERRED
for each row execute function each_offering_at_least_one_session_f();

drop trigger if exists each_offering_at_least_one_session_t2 on Sessions;
create trigger each_offering_at_least_one_session_t2
before delete on Sessions
for each row execute function each_offering_at_least_one_session_f();

--each session is on a specific weekday (Monday to Friday)

create or replace function sessions_on_weekdays_f()
returns trigger as $$
    declare
        dow integer;
    begin
        select extract(dow from NEW.date) into dow;
        if dow < 1 or dow > 5 then
            raise 'Each session is on a specific weekday';
        end if;
        return NEW;
    end;
$$ language plpgsql;

drop trigger if exists sessions_on_weekdays_t on Sessions;
create trigger sessions_on_weekdays_t
before insert or update on Sessions
for each row execute function sessions_on_weekdays_f();

-- session mustn't end after 6

create or replace function sessions_end_by_18_and_not_during_12_14_f1()
returns trigger as $$
    declare
        dur integer;
        endtime integer;
    begin
        select duration into dur
        from (Sessions natural join Offerings) natural join Courses
        where offering_id = NEW.offering_id;
        endtime := NEW.start_time + dur;
        if endtime > 18 then
            raise 'Session should not end after 6pm';
        end if;
        if NEW.start_time < 14 and endtime > 12 then
            raise 'Session cannot take place during 12-2pm';
        end if;
        return NEW;
    end;
$$ language plpgsql;

drop trigger if exists sessions_end_by_18_and_not_during_12_14_t1 on Sessions;
create trigger sessions_end_by_18_and_not_during_12_14_t1
before insert or update on Sessions
for each row execute function sessions_end_by_18_and_not_during_12_14_f1();

create or replace function sessions_end_by_18_and_not_during_12_14_f2()
returns trigger as $$
    declare
        num_violated_sessions integer;
    begin
        select count(*) into num_violated_sessions
        from (Courses natural join Offerings) natural join Sessions
        where course_id = NEW.course_id and (start_time + NEW.duration > 18 or (start_time < 14 and start_time + NEW.duration >= 12));
        
        if num_violated_sessions > 0 then
            raise 'Session should not end after 6pm or take place during 12-2pm';
        end if;
        return NEW;
    end;
$$ language plpgsql;

drop trigger if exists sessions_end_by_18_and_not_during_12_14_t2 on Courses;
create trigger sessions_end_by_18_and_not_during_12_14_t2
before insert or update on Courses
for each row execute function sessions_end_by_18_and_not_during_12_14_f2();

-- The sessions for a course offering are numbered consecutively starting from 1 (we just check that it is  1 + max;

create or replace function consecutive_session_id()
returns trigger as $$
    begin
        if (select COALESCE(MAX(sid), 0) from Sessions where NEW.offering_id = offering_id) + 1 <> NEW.sid then
            raise 'Session ids must be consecutive';
        end if;
        return NEW;
    end;
$$ language plpgsql;

drop trigger if exists consecutive_session_id_t on Sessions;
create trigger consecutive_session_id_t
before insert on Sessions
for each row execute function consecutive_session_id();

-- Each room can be used to conduct at most one course session at any time.

create or replace function one_session_per_room_at_a_time_f()
returns trigger as $$
    declare
        has_clash integer;
        new_duration integer;
    begin
    	select duration into new_duration from Courses C join Offerings O2 on C.course_id = O2.course_id where O2.offering_id = NEW.offering_id;
        select 1 into has_clash
        from Sessions S inner join Offerings O on S.offering_id = O.offering_id inner join Courses C on O.course_id = C.course_id
        where (
            S.sid <> NEW.sid and
            S.room = NEW.room and
            S.date = NEW.date and
            (
            	LEAST(C.duration + S.start_time, NEW.start_time + new_duration) > GREATEST(S.start_time, NEW.start_time)
            )
        );
        if has_clash = 1 then
            raise 'Each room can be used to conduct at most one course session at any time.';
            return NULL;
        end if;
        return NEW;
    end;
$$ language plpgsql;

drop trigger if exists one_session_per_room_at_a_time_t on Sessions;
create trigger one_session_per_room_at_a_time_t
before insert or update on Sessions
for each row execute function one_session_per_room_at_a_time_f();

-- number of remaining redemptions for package mustn't be more than number of free registrations

create or replace function remaining_redemptions_not_more_than_free_registrations_f()
returns trigger as $$
    declare
        num_free integer;
    begin
        select num_free_registrations into num_free
        from Course_packages
        where package_id = NEW.package_id;
        if NEW.num_remaining_redemptions > num_free then
            raise 'Number of remaining redemptions for package cannot be more than number of free registrations';
            return NULL;
        end if;
        return NEW;
    end;
$$ language plpgsql;

drop trigger if exists remaining_redemptions_not_more_than_free_registrations_t on Buys;
create trigger remaining_redemptions_not_more_than_free_registrations_t
before insert or update on Buys
for each row execute function remaining_redemptions_not_more_than_free_registrations_f();

-- Each customer can have at most one active or partially active package.

create or replace function one_active_package_per_customer_f()
returns trigger as $$
    declare
        has_other_package integer;
        cid integer;
    begin
        select cust_id into cid
        from Credit_cards
        where number = NEW.number;

        select 1 into has_other_package
        from Buys natural join Credit_cards
        where (
            cust_id = cid and
            num_remaining_redemptions * NEW.num_remaining_redemptions <> 0 and
            (
                date <> NEW.date or
                package_id <> NEW.package_id
            )
        );
        if has_other_package = 1 then
            raise 'Each customer can have at most one active or partially active package.';
            return NULL;
        end if;
        return NEW;
    end;
$$ language plpgsql;

drop trigger if exists one_active_package_per_customer_t on Buys;
create trigger one_active_package_per_customer_t
before insert or update on Buys
for each row execute function one_active_package_per_customer_f();


--The registration deadline for a course offering must be at least 10 days before its start date.

create or replace function registration_ten_days_before_f1()
returns trigger as $$
    declare
        start_date date;
    begin
        select min(date) into start_date
        from Sessions
        where offering_id = NEW.offering_id;
        if start_date - 10 < NEW.registration_deadline then
            raise 'The registration deadline for a course offering must be at least 10 days before its start date.';
        end if;
        return NEw;
    end;
$$ language plpgsql;

create or replace function registration_ten_days_before_f2()
returns trigger as $$
    declare
        start_date date;
        reg_deadline date;
    begin
        select min(date) into start_date
        from Sessions
        where offering_id = NEW.offering_id;

        select registration_deadline into reg_deadline
        from Offerings
        where offering_id = NEW.offering_id;

        if start_date - 10 < reg_deadline then
            raise 'The registration deadline for a course offering must be at least 10 days before its start date.';
        end if;
        return NEW;
    end;
$$ language plpgsql;

drop trigger if exists registration_ten_days_before_t1 on Offerings;
create trigger registration_ten_days_before_t1
before insert or update on Offerings
for each row execute function registration_ten_days_before_f1();

drop trigger if exists  registration_ten_days_before_t2 on Sessions;
create trigger registration_ten_days_before_t2
before insert on Sessions
for each row execute function registration_ten_days_before_f2();

-- employee total participation in part time or full time
create or replace function employee_in_part_or_full_time_f()
returns trigger as $$
    declare
        changedEid integer;
    begin
        if tg_op = 'INSERT' then
            -- inserting into employees
            changedEid := NEW.eid;
        else
            -- deleting from part/full time
            changedEid := OLD.eid;
        end if;
        -- deleting from employees no trigger because:
        -- -- will cascade;

        -- inserting into full/part time no trigger because:
        -- -- FK enforces already;

        if exists(select 1 from Employees where eid = changedEid) and
           not exists(select 1 from Full_time_Emp where eid = changedEid) and
           not exists(select 1 from Part_time_Emp where eid = changedEid)           
           then
            raise 'All employees must either be part or full time';
        end if;
        return null;
    end;
$$ language plpgsql;

drop trigger if exists employee_in_part_or_full_time_t1 on Employees;
create constraint trigger employee_in_part_or_full_time_t1
after insert on Employees
DEFERRABLE INITIALLY DEFERRED
for each row execute function employee_in_part_or_full_time_f();

drop trigger if exists employee_in_part_or_full_time_t2 on Part_time_Emp;
create constraint trigger employee_in_part_or_full_time_t2
after delete or update on Part_time_Emp
DEFERRABLE INITIALLY DEFERRED
for each row execute function employee_in_part_or_full_time_f();

drop trigger if exists employee_in_part_or_full_time_t3 on Full_time_Emp;
create constraint trigger employee_in_part_or_full_time_t3
after delete or update on Full_time_Emp
DEFERRABLE INITIALLY DEFERRED
for each row execute function employee_in_part_or_full_time_f();

-- employee total participation in admin / instr / manager
create or replace function employee_is_administrator_or_instructor_or_manager_f()
returns trigger as $$
    declare
        changedEid integer;
    begin
        if tg_op = 'INSERT' then
            -- inserting into employees
            changedEid := NEW.eid;
        else
            -- deleting from admin/instr/manager time
            changedEid := OLD.eid;
        end if;
        -- deleting from employees no trigger because:
        -- -- will cascade;

        -- inserting into admin/instr/manager no trigger because:
        -- -- FK enforces already;

        if exists(select 1 from Employees where eid = changedEid) and
           not exists(select 1 from Administrators where eid = changedEid) and
           not exists(select 1 from Instructors where eid = changedEid) and
           not exists(select 1 from Managers where eid = changedEid)
           then
            raise 'All employees must either be an administrator, an instructor, or a manager';
        end if;
        return null;
    end;
$$ language plpgsql;

drop trigger if exists employee_is_administrator_or_instructor_or_manager_t1 on Employees;
create constraint trigger employee_is_administrator_or_instructor_or_manager_t1
after insert on Employees
DEFERRABLE INITIALLY DEFERRED
for each row execute function employee_is_administrator_or_instructor_or_manager_f();

drop trigger if exists employee_is_administrator_or_instructor_or_manager_t2 on Administrators;
create constraint trigger employee_is_administrator_or_instructor_or_manager_t2
after delete or update on Administrators
DEFERRABLE INITIALLY DEFERRED
for each row execute function employee_is_administrator_or_instructor_or_manager_f();

drop trigger if exists employee_in_part_or_full_time_t3 on Instructors;
create constraint trigger employee_in_part_or_full_time_t3
after delete or update on Instructors
DEFERRABLE INITIALLY DEFERRED
for each row execute function employee_is_administrator_or_instructor_or_manager_f();

drop trigger if exists employee_in_part_or_full_time_t4 on Managers;
create constraint trigger employee_in_part_or_full_time_t4
after delete or update on Managers
DEFERRABLE INITIALLY DEFERRED
for each row execute function employee_is_administrator_or_instructor_or_manager_f();

-- course session instructor must be specialized in that area
create or replace function session_instructor_is_specialized_f()
returns trigger as $$
    declare
        changedEid integer;
    begin
        if not exists(select 1 from Specializes s inner join Course_areas ca on ca.name = s.name inner join Courses c on ca.name = c.area inner join Offerings O on c.course_id = O.course_id where s.eid = NEW.instructor and O.offering_id = NEW.offering_id)  then
            raise 'An instructor teaching a course session must be specialized in that area';
        end if;
        return NEW;
    end;
$$ language plpgsql;

drop trigger if exists  session_instructor_is_specialized_t on Sessions;
create trigger session_instructor_is_specialized_t
before insert or update on Sessions
for each row execute function session_instructor_is_specialized_f();

-- Each instructor must not be assigned to teach two consecutive course sessions;
create or replace function instructor_no_consecutive_sessions_f()
returns trigger as $$
    begin
        if exists(select 1 from Sessions S inner join Offerings O on S.offering_id = O.offering_id inner join Courses C on O.course_id = C.course_id where NEW.instructor = S.instructor and S.date = NEW.date and NEW.start_time = S.start_time + C.duration)  then
            raise 'An instructor cannot teach two courses consecutively';
        end if;
        return NEW;
    end;
$$ language plpgsql;

drop trigger if exists  instructor_no_consecutive_sessions_t on Sessions;
create trigger instructor_no_consecutive_sessions_t
before insert or update on Sessions
for each row execute function instructor_no_consecutive_sessions_f();

-- Each part-time instructor must not teach more than 30 hours for each month.
create or replace function instructor_max_30h_per_month_f()
returns trigger as $$
    begin
        if (select sum(C.duration) from Sessions S inner join Offerings O on S.offering_id = O.offering_id inner join Courses C on O.course_id = C.course_id where S.instructor = NEW.instructor and (extract(year from NEW.date)) = (extract(year from S.date)) and (extract(month from NEW.date)) = (extract(month from S.date))) > 30  then
            raise 'An instructor cannot teach more than 30 hours for each month';
        end if;
        return NEW;
    end;
$$ language plpgsql;

drop trigger if exists  instructor_max_30h_per_month_t on Sessions;
create trigger instructor_max_30h_per_month_t
after insert or update on Sessions
for each row execute function instructor_max_30h_per_month_f();

-- Each instructor can teach at most one course session at any hour.
create or replace function instructor_no_overlapping_sessions_f()
returns trigger as $$
    declare
        new_duration integer;
    begin
        select duration from Courses C join Offerings O2 on C.course_id = O2.course_id where O2.offering_id = NEW.offering_id into new_duration;
        if exists(select 1 from Sessions S inner join Offerings O on S.offering_id = O.offering_id inner join Courses C on O.course_id = C.course_id where NEW.sid <> S.sid and NEW.instructor = S.instructor and S.date = NEW.date and LEAST(C.duration + S.start_time, NEW.start_time + new_duration) > GREATEST(S.start_time, NEW.start_time))  then
            raise 'An instructor cannot teach two courses simultaneously';
        end if;
        return NEW;
    end;
$$ language plpgsql;

drop trigger if exists  instructor_no_overlapping_sessions_t on Sessions;
create trigger instructor_no_overlapping_sessions_t
before insert or update on Sessions
for each row execute function instructor_no_overlapping_sessions_f();

