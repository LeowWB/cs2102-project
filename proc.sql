DROP TYPE IF EXISTS employee_status CASCADE;
DROP TYPE IF EXISTS employee_category CASCADE;
DROP TYPE IF EXISTS session_info CASCADE;
DROP TYPE IF EXISTS payment_method CASCADE;
DROP TYPE IF EXISTS redeemed_session_info CASCADE;
DROP TYPE IF EXISTS course_package_info CASCADE;
CREATE TYPE employee_status AS ENUM ('full_time', 'part_time');
CREATE TYPE employee_category AS ENUM ('administrator', 'manager', 'instructor');
CREATE TYPE session_info AS (date date, start_time int, room_id int);
CREATE TYPE payment_method AS ENUM ('credit_card', 'course_package');
CREATE TYPE redeemed_session_info AS (course_name text, session_date date, session_start_hour int);
CREATE TYPE course_package_info AS (pkg_name text, purchase_date timestamp, price int, num_free_sessions int, num_unredeemed_sessions int, redeemed_sessions_info redeemed_session_info[]);

CREATE OR REPLACE VIEW CourseOfferingSessions AS 
	SELECT C.course_id, C.title, C.description, C.duration, C.area, O.offering_id, O.launch_date, O.fees, O.target_number_registrations, O.registration_deadline, O.handler, S.sid, S.instructor, S.date, S.start_time, S.room
	FROM Sessions S 
	JOIN Offerings O ON S.offering_id = O.offering_id 
	JOIN Courses C ON O.course_id = C.course_id;

CREATE OR REPLACE FUNCTION does_customer_exist(_cust_id int) 
RETURNS boolean AS $$
	SELECT EXISTS(
		SELECT 1
		FROM Customers
		WHERE cust_id = _cust_id
	);
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION does_employee_exist(_emp_id int) 
RETURNS boolean AS $$
	SELECT EXISTS(
		SELECT 1
		FROM Employees
		WHERE eid = _emp_id
	);
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION does_administrator_exist(_admin_id int) 
RETURNS boolean AS $$
	SELECT EXISTS(
		SELECT 1
		FROM Administrators
		WHERE eid = _admin_id
	);
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION does_instructor_exist(_instr_id int) 
RETURNS boolean AS $$
	SELECT EXISTS(
		SELECT 1
		FROM Instructors
		WHERE eid = _instr_id
	);
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION does_course_exist(_course_id int) 
RETURNS boolean AS $$
	SELECT EXISTS(
		SELECT 1
		FROM Courses
		WHERE course_id = _course_id
	);
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION does_offering_exist(_offering_id int) 
RETURNS boolean AS $$
	SELECT EXISTS(
		SELECT 1
		FROM Offerings 
		WHERE offering_id = _offering_id
	);
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION does_session_exist(_offering_id int, _session_id int) 
RETURNS boolean AS $$
	SELECT EXISTS(
		SELECT 1
		FROM Sessions 
		WHERE offering_id = _offering_id
			AND sid = _session_id
	);
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION does_room_exist(_room_id int) 
RETURNS boolean AS $$
	SELECT EXISTS(
		SELECT 1
		FROM Rooms 
		WHERE rid = _room_id
	);
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION get_latest_credit_card(_cust_id int) 
RETURNS Credit_cards AS $$
	SELECT *
	FROM Credit_cards
	WHERE cust_id = _cust_id
	ORDER BY from_date DESC
	LIMIT 1;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION get_latest_course_package(_cust_id int) 
RETURNS Buys AS $$
	SELECT B.date, B.package_id, B.number, B.num_remaining_redemptions
	FROM Buys B
	JOIN Credit_cards CC ON B.number = CC.number
	WHERE cust_id = _cust_id
	ORDER BY B.date DESC
	LIMIT 1;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION get_session_seating_capacity(_offering_id int, _session_id int)
RETURNS int AS $$
	SELECT R.seating_capacity
	FROM Sessions S
	JOIN Rooms R ON S.room = R.rid
	WHERE S.offering_id = _offering_id
		AND S.sid = _session_id;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION get_instructor_month_hours(_emp_id int, _year int, _month int) 
RETURNS bigint AS $$
	SELECT COALESCE(SUM(duration), 0)
	FROM CourseOfferingSessions
	WHERE instructor = _emp_id 
		AND EXTRACT(year FROM date) = _year 
		AND EXTRACT(month FROM date) = _month;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION get_session_timestamp(_offering_id int, _session_id int) 
RETURNS timestamp AS $$
	SELECT date + (start_time * INTERVAL '1 hour')
	FROM Sessions
	WHERE offering_id = _offering_id
		AND sid = _session_id;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION do_ranges_overlap(_start1 int, _end1 int, _start2 int, _end2 int) 
RETURNS boolean AS $$
	SELECT _end1 > _start2 AND _start1 < _end2;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION do_sessions_clash(_start1 int, _duration1 int, _start2 int, _duration2 int) 
RETURNS boolean AS $$
	SELECT do_ranges_overlap(_start1, _start1 + _duration1, _start2, _start2 + _duration2);
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION is_session_legal(_date date)
RETURNS boolean AS $$
	SELECT EXTRACT(dow FROM _date)::int IN (1, 2, 3, 4, 5);
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION is_session_legal(_start_time int, _duration int)
RETURNS boolean AS $$
	SELECT _start_time >= 9 AND (_start_time + _duration) <= 18 AND NOT do_sessions_clash(_start_time, _duration, 12, 2);
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION is_session_allowed(_room_id int, _date date, _start_time int, _duration int) 
RETURNS boolean AS $$
	SELECT NOT EXISTS(
		SELECT 1
		FROM CourseOfferingSessions
		WHERE room = _room_id 
			AND date = _date 
			AND do_sessions_clash(_start_time, _duration, start_time, duration)
	);
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION do_instructor_sessions_clash(_start1 int, _duration1 int, _start2 int, _duration2 int) 
RETURNS boolean AS $$
DECLARE
	_break_time int;
BEGIN
	_break_time := 1;
	RETURN do_ranges_overlap(_start1, _start1 + _duration1 + _break_time, _start2, _start2 + _duration2 + _break_time);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION is_instructor_session_allowed(_emp_id int, _date date, _start_time int, _duration int) 
RETURNS boolean AS $$
	SELECT NOT EXISTS(
		SELECT 1
		FROM CourseOfferingSessions
		WHERE instructor = _emp_id 
			AND date = _date 
			AND do_instructor_sessions_clash(_start_time, _duration, start_time, duration)
	);
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION does_session_exceed_part_time_hours(_emp_id int, _date date, _duration int)
RETURNS boolean AS $$
	SELECT (get_instructor_month_hours(_emp_id, EXTRACT(year FROM _date)::int, EXTRACT(month FROM _date)::int) + _duration > 30);
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION get_session_num_registrations(_offering_id int, _session_id int) 
RETURNS bigint AS $$
	SELECT
	(
		SELECT COUNT(*) 
		FROM Registers 
		WHERE offering_id = _offering_id AND sid = _session_id
	) +
	(
		SELECT COUNT(*) 
		FROM Redeems 
		WHERE offering_id = _offering_id AND sid = _session_id
	) -
	(
		SELECT COUNT(*) 
		FROM Cancels 
		WHERE offering_id = _offering_id AND sid = _session_id
	);
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION is_session_available(_offering_id int, _session_id int)
RETURNS boolean AS $$
	SELECT (get_session_seating_capacity(_offering_id, _session_id) - get_session_num_registrations(_offering_id, _session_id) > 0);
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION is_registered_for_offering(_cust_id int, _offering_id int) 
RETURNS boolean AS $$
	SELECT
	((
		SELECT COUNT(*) 
		FROM Registers REG
		JOIN Credit_cards CC ON REG.number = CC.number
		WHERE CC.cust_id = _cust_id 
			AND REG.offering_id = _offering_id
	) +
	(
		SELECT COUNT(*) 
		FROM Redeems RED
		JOIN Credit_cards CC ON RED.number = CC.number
		WHERE CC.cust_id = _cust_id 
			AND RED.offering_id = _offering_id
	) -
	(
		SELECT COUNT(*) 
		FROM Cancels
		WHERE cust_id = _cust_id 
			AND offering_id = _offering_id
	)) > 0;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION is_registered_for_session(_cust_id int, _offering_id int, _session_id int) 
RETURNS boolean AS $$
	SELECT
	((
		SELECT COUNT(*) 
		FROM Registers REG
		JOIN Credit_cards CC ON REG.number = CC.number
		WHERE CC.cust_id = _cust_id
			AND REG.offering_id = _offering_id
			AND REG.sid = _session_id
	) +
	(
		SELECT COUNT(*) 
		FROM Redeems RED
		JOIN Credit_cards CC ON RED.number = CC.number
		WHERE CC.cust_id = _cust_id
			AND RED.offering_id = _offering_id
			AND RED.sid = _session_id
	) -
	(
		SELECT COUNT(*) 
		FROM Cancels
		WHERE cust_id = _cust_id
			AND offering_id = _offering_id
			AND sid = _session_id
	)) > 0;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION get_registered_session(_cust_id int, _offering_id int, OUT session_id int, OUT paid_by payment_method, OUT paid_date timestamp, OUT cc_num text, OUT course_package_id int, OUT package_buys_date timestamp)
RETURNS record AS $$
DECLARE
	registers_r Registers;
	redeems_r Redeems;
BEGIN
	IF (NOT is_registered_for_offering(_cust_id, _offering_id)) THEN
		RETURN;
	END IF;
	
	SELECT REG.sid, REG.date, CC.number INTO registers_r.sid, registers_r.date, registers_r.number
	FROM Registers REG
	JOIN Credit_cards CC ON REG.number = CC.number
	WHERE CC.cust_id = _cust_id
		AND REG.offering_id = _offering_id
	ORDER BY REG.date DESC
	LIMIT 1;
	
	SELECT RED.sid, RED.date, CC.number, RED.package_id, RED.buys_date INTO redeems_r.sid, redeems_r.date, redeems_r.number, redeems_r.package_id, redeems_r.buys_date
	FROM Redeems RED
	JOIN Credit_cards CC ON RED.number = CC.number
	WHERE CC.cust_id = _cust_id
		AND RED.offering_id = _offering_id
	ORDER BY RED.date DESC
	LIMIT 1;
	
	IF (registers_r IS NULL) THEN
		paid_by := 'course_package';
	ELSIF (redeems_r IS NULL) THEN
		paid_by := 'credit_card';
	ELSIF (registers_r.date > redeems_r.date) THEN
		paid_by := 'credit_card';
	ELSE
		paid_by := 'course_package';
	END IF;
	IF (paid_by = 'credit_card') THEN
		session_id := registers_r.sid;
		paid_date := registers_r.date;
		cc_num := registers_r.number;
	ELSE
		session_id := redeems_r.sid;
		paid_date := redeems_r.date;
		cc_num := redeems_r.number;
		course_package_id := redeems_r.package_id;
		package_buys_date := redeems_r.buys_date;
	END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_offering_seating_capacity(_offering_id int) 
RETURNS bigint AS $$
	SELECT SUM(seating_capacity)
	FROM Sessions S JOIN Rooms R ON S.room = R.rid
	WHERE offering_id = _offering_id;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION offering_reg_deadline_passed(_offering_id int, _date date) 
RETURNS boolean AS $$
	SELECT O.registration_deadline > _date
	FROM Offerings O
	WHERE O.offering_id = _offering_id;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION get_most_recent_package(IN _cc_num varchar(19), OUT date timestamp, OUT package_id int, OUT num_remaining_redemptions int, OUT name text, OUT price int, OUT num_free_registrations int) 
RETURNS record AS $$
	SELECT B.date, B.package_id, B.num_remaining_redemptions, P.name, P.price, P.num_free_registrations
	FROM Buys B JOIN Course_packages P ON B.package_id = P.package_id 
	WHERE B.number = _cc_num
	ORDER BY B.date desc
	LIMIT 1;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION get_redeemed_sessions(_date timestamp, _pkg_id int, _cc_num varchar(19)) RETURNS redeemed_session_info[] AS $$
DECLARE
	_arr redeemed_session_info[];
	_curs CURSOR FOR (
		SELECT S.offering_id, S.date, S.start_time
		FROM Redeems R JOIN Sessions S ON R.sid = S.sid AND R.offering_id = S.offering_id
		WHERE R.buys_date = _date 
			AND R.package_id = _pkg_id 
			AND R.number = _cc_num
		ORDER BY S.date, S.start_time
	);
	r record;
	_first_access boolean;
	_course_name text;
BEGIN
	_first_access := true;
	OPEN _curs;
	LOOP
		FETCH _curs INTO r;
		EXIT WHEN NOT FOUND;
		IF _first_access THEN
			SELECT C.title INTO _course_name
			FROM Offerings O JOIN Courses C ON O.course_id = C.course_id
			WHERE O.offering_id = r.offering_id;
			_first_access := false;
		END IF;
		-- Add session info to array
		_arr := array_append(_arr, ROW(_course_name, r.date, r.start_time));
	END LOOP;
	CLOSE _curs;
	RETURN _arr;
END;
$$ LANGUAGE plpgsql;

-- TODO: Improve efficiency, get without using cursor?
CREATE OR REPLACE FUNCTION get_unsorted_available_course_offerings(_curr_date date) 
RETURNS TABLE(course_title text, course_area text, start_date date, end_date date, reg_deadline date, course_fees int, num_rem_seats int) AS $$
DECLARE
	_curs CURSOR FOR (
		SELECT O.offering_id, O.course_id, O.registration_deadline, O.fees
		FROM Offerings O
		WHERE _curr_date <= O.registration_deadline
	);
	r record;
BEGIN
	OPEN _curs;
	LOOP
		FETCH _curs INTO r;
		EXIT WHEN NOT FOUND;
		SELECT C.title, C.area INTO course_title, course_area
		FROM Courses C
		WHERE C.course_id = r.course_id;
		SELECT min(S.date), max(S.date) INTO start_date, end_date
		FROM Sessions S
		WHERE S.offering_id = r.offering_id;
		reg_deadline := r.registration_deadline;
		course_fees := r.fees;
		SELECT sum(get_session_num_registrations(r.offering_id, S.sid)) INTO num_rem_seats 
		FROM Sessions S
		WHERE S.offering_id = r.offering_id;
		RETURN NEXT;
	END LOOP;
	CLOSE _curs;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION get_work_days(_salary_type char(9), _join_date date, _depart_date date) RETURNS int AS $$
DECLARE
	_num_days_in_month int;
	_curr_month int;
	_curr_year int;
	_join_month int;
	_join_year int;
	_first_work_day int;
BEGIN
	-- Work days are not applicable to part-time employees
	IF _salary_type = 'part_time' THEN
		RETURN NULL;
	END IF;
	SELECT extract(days FROM date_trunc('month', now()) + INTERVAL '1 month - 1 day') INTO _num_days_in_month;
	SELECT extract(month FROM now()) INTO _curr_month;
	SELECT extract(year FROM now()) INTO _curr_year;
	SELECT extract(month FROM _join_date) INTO _join_month;
	SELECT extract(year FROM _join_date) INTO _join_year;
	IF _join_month = _curr_month AND _join_year = _curr_year THEN
		SELECT extract(days FROM _join_date) INTO _first_work_day;
	ELSE 
		_first_work_day = 1;
	END IF;
	RETURN COALESCE(extract(days FROM _depart_date), _num_days_in_month) - _first_work_day + 1;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_work_hours(_eid int, _salary_type char(9)) RETURNS bigint AS $$
DECLARE 
	_hours bigint;
BEGIN
	-- Work hours are not applicable to full-time employees 
	IF _salary_type = 'full_time' THEN
		RETURN NULL;
	END IF;

	SELECT sum(T.duration) INTO _hours
	FROM CourseOfferingSessions T
	WHERE T.instructor = _eid
		AND extract(month from now()) = extract(month from T.date)
	GROUP BY T.instructor;
	
	RETURN _hours;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION calculate_salary(_eid int, _salary_type char(9), _join_date date, _depart_date date, _monthly_salary int, _hourly_rate int) RETURNS int AS $$
DECLARE
	_num_work_quantity int;
	_num_days_in_month int;
BEGIN
	IF _salary_type = 'full_time' THEN
		SELECT extract(days FROM date_trunc('month', now()) + INTERVAL '1 month - 1 day') INTO _num_days_in_month;
		_num_work_quantity := get_work_days(_salary_type, _join_date, _depart_date);
		RETURN (_monthly_salary * _num_work_quantity) / _num_days_in_month;
	ELSE
		-- salary_type is either "full_time" or "part_time"
		_num_work_quantity := get_work_hours(_eid, _salary_type);
		-- Part-time instructor did not teach any sessions this month
		IF _num_work_quantity IS NULL THEN
			RETURN 0;
		END IF;
		RETURN _hourly_rate * _num_work_quantity;
	END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_inactive_customer_ids() 
RETURNS TABLE(cust_id int) AS $$
DECLARE
	_curr_month int;
	_curr_year int;
BEGIN
	SELECT extract(month FROM now()) INTO _curr_month;
	SELECT extract(year FROM now()) INTO _curr_year;

	-- Customers who did not register/redeem for an offering in last 6 months
	RETURN QUERY
	SELECT C.cust_id
	FROM Customers C NATURAL JOIN Credit_cards Cc JOIN Registers Rg ON Cc.number = Rg.number
	WHERE Rg.date >= CURRENT_DATE - INTERVAL '6 months'
	UNION
	SELECT C.cust_id
	FROM Customers C NATURAL JOIN Credit_cards Cc JOIN Redeems Rd ON Cc.number = Rd.number
	WHERE Rd.date >= CURRENT_DATE - INTERVAL '6 months';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_registered_and_redeemed_offerings(_cc_num varchar(19)) 
RETURNS TABLE(offering_id int, date date) AS $$
BEGIN
	-- Customers who did not register/redeem for an offering in last 6 months
	RETURN QUERY
	SELECT Reg.offering_id, Reg.date
	FROM Registers Reg
	WHERE Reg.number = _cc_num
	UNION
	SELECT Red.offering_id, Red.date
	FROM Redeems Red
	WHERE Red.number = _cc_num;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_interested_course_areas(_cust_id int) 
RETURNS TABLE(area text) AS $$
BEGIN
	RETURN QUERY
	SELECT C.area
	FROM (
		SELECT O.offering_id
		FROM get_registered_and_redeemed_offerings(get_latest_credit_card(_cust_id)) O
		ORDER BY O.date desc
		LIMIT 3
	) as OfferingID NATURAL JOIN Offerings NATURAL JOIN Courses C;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_unsorted_courses_to_promote() 
RETURNS TABLE(cust_id int, cust_name text, course_area text, course_id int, course_title text, launch_date date, reg_deadline date, course_fees int) AS $$
DECLARE
	-- get_inactive_customers() (did not register for an offering in last 6 months)
	_cust_curs CURSOR FOR (
		SELECT *
		FROM get_inactive_customer_ids() NATURAL JOIN Customers
	);
	r record;
	_num_registered_offerings int;
BEGIN
	OPEN _cust_curs;
	LOOP
		FETCH _cust_curs INTO r;
		EXIT WHEN NOT FOUND;
		-- get_interested_course_areas(cust_id) (areas in last 3 offerings cust had)
		SELECT count(A.area) INTO _num_registered_offerings
		FROM get_interested_course_areas(r.cust_id) A;
		IF _num_registered_offerings = 0 THEN
			-- Assume all course areas are interesting
			RETURN QUERY
			SELECT r.cust_id, r.name, C.area, C.course_id, C.title, O.launch_date, O.registration_deadline, O.fees
			FROM Course_areas A JOIN Courses C ON A.name = C.area NATURAL JOIN Offerings O
			WHERE O.registration_deadline > CURRENT_DATE;
		ELSE
			-- Assume only those areas are interesting
			RETURN QUERY
			SELECT r.cust_id, r.name, C.area, C.course_id, C.title, O.launch_date, O.registration_deadline, O.fees
			FROM get_interested_course_areas(r.cust_id) A JOIN Courses C ON A.name = C.area NATURAL JOIN Offerings O
			WHERE registration_deadline > CURRENT_DATE;
		END IF;
	END LOOP;
	CLOSE _cust_curs;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_num_reg_offerings(_offering_id int) 
RETURNS int AS $$
	SELECT sum(Registrations.num_reg)::INTEGER
	FROM (
		SELECT get_session_num_registrations(O.offering_id, S.sid) AS num_reg, O.offering_id
		FROM Offerings O NATURAL JOIN Sessions S
		WHERE O.offering_id = _offering_id ) as Registrations
	GROUP BY Registrations.offering_id;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION num_reg_latest_offering(_course_id int) 
RETURNS int AS $$
	WITH CO AS (
		SELECT * 
		FROM Courses C NATURAL JOIN Offerings
		WHERE C.course_id = _course_id
	)
	SELECT get_num_reg_offerings(CO.offering_id)
	FROM CO
	WHERE CO.launch_date >= ALL (
		SELECT CO2.launch_date
		FROM CO CO2
	);
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION get_popular_courses() 
RETURNS TABLE(course_id int, course_title text, course_area text, num_offerings int, num_reg_latest_offering int) AS $$
BEGIN
	RETURN QUERY
	-- Courses with >= 2 offerings this year
	WITH C AS (
		SELECT Co.course_id, Co.title, Co.area
		FROM Courses Co NATURAL JOIN Offerings O
		WHERE extract(year FROM O.launch_date) = extract(year FROM now())
		GROUP BY Co.course_id
		HAVING count(*) >= 2 )
	-- Courses whose later offerings have higher reg than earlier ones
	SELECT course_id, course_title, course_area, count(*) AS num_offerings, num_reg_latest_offering(C2.course_id) AS num_reg
	FROM (
		SELECT C.course_id, C.title AS course_title, C.area AS course_area
		FROM C
		WHERE NOT EXISTS (
			SELECT 1
			FROM Offerings O1, Offerings O2
			WHERE O1.launch_date > O2.launch_date
				AND C.course_id = O1.course_id
				AND C.course_id = O2.course_id
				AND get_num_reg_offerings(O1.offering_id) <= get_num_reg_offerings(O2.offering_id) )
		) as C2 NATURAL JOIN Offerings O
	WHERE extract(year FROM O.launch_date) = extract(year FROM now())
	GROUP BY C2.course_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_num_course_areas(_eid int) RETURNS bigint as $$
	SELECT count(*)
	FROM Course_areas
	WHERE manager = _eid;
$$ LANGUAGE sql;

-- Date of latest session of offering
CREATE OR REPLACE FUNCTION get_offering_end_date(_offering_id int) RETURNS date as $$
	SELECT S.date
	FROM Offerings O NATURAL JOIN Sessions S
	WHERE O.offering_id = _offering_id
		AND date >= ALL (
			select S.date
			FROM Sessions
			WHERE S.offering_id = _offering_id
		);
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION get_num_course_offerings(_eid int) RETURNS int as $$
	SELECT count(*)::INTEGER AS count
	FROM Offerings O NATURAL JOIN Courses C JOIN Course_areas A ON C.area = A.name
	WHERE A.manager = _eid
		AND extract(year FROM get_offering_end_date(O.offering_id)) = extract(year FROM now());
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION get_total_reg_fees_managed(IN eid int, OUT net_fees int, OUT title text) RETURNS record as $$
BEGIN
	WITH O AS (
		SELECT *
		FROM Offerings O NATURAL JOIN Courses C JOIN Course_areas A ON C.area = A.name
		WHERE A.manager = _eid
			AND extract(year FROM get_offering_end_date(O.offering_id)) = extract(year FROM now())
	)
	SELECT sum(reg_fees) - sum(refund_fees) + sum(redeem_fees) AS net_fees, title
	FROM (
		SELECT fees * (
			SELECT count(*)
			FROM O NATURAL JOIN Registers
		) AS reg_fees, (
			SELECT sum(Cancels.refund_amt)
			FROM O NATURAL JOIN Cancels
		) AS refund_fees, (
			-- Round down to nearest dollar by dividing by 100 first then * 100 after truncated division
			SELECT sum(((P.price / 100) / P.num_free_registrations) * 100)
			FROM O NATURAL JOIN Redeems NATURAL JOIN Course_packages P
		) AS redeem_fees, O.title
		FROM O
	) as Fees;
END;
$$ LANGUAGE plpgsql;

-- 1
/* This routine is used to add a new employee. The inputs to the routine include the following: name, home address, contact number, email address, salary information (i.e., monthly salary for a full-time employee or hourly rate for a part-time employee), date that the employee joined the company, the employee category (manager, administrator, or instructor), and a (possibly empty) set of course areas. If the new employee is a manager, the set of course areas refers to the areas that are managed by the manager. If the new employee is an instructor, the set of course areas refers to the instructor’s specialization areas. The set of course areas must be empty if the new employee is a administrator; and non-empty, otherwise. The employee identifier is generated by the system. 
The set of course areas can be empty for managers. */
CREATE OR REPLACE PROCEDURE add_employee(_name text, _address text, _phone text, _email text, _status employee_status, _salary int, _join_date date, _category employee_category, _course_areas text[]) AS $$
DECLARE
	_job_type text;
	_emp_id int;
	_area text;
BEGIN
	IF ((_category = 'administrator' OR _category = 'manager') AND _status = 'part_time') THEN
		RAISE EXCEPTION 'Administrators or managers cannot be part-time employees.';
	END IF;
	IF (_category = 'administrator' AND cardinality(_course_areas) > 0) THEN
		RAISE EXCEPTION 'Course areas must be empty for Administrators.';
	END IF;
	IF (_category = 'instructor' AND cardinality(_course_areas) = 0) THEN
		RAISE EXCEPTION 'Course areas must not be empty for non-Administrators.';
	END IF;
	
	_job_type := _category;
	IF (_job_type = 'instructor') THEN
		_job_type := _status || '_' || _job_type;
	END IF;
	
	INSERT INTO Employees(salary_type, job_type, name, phone, address, email, join_date) 
	VALUES (_status, _job_type, _name, _phone, _address, _email, _join_date)
	RETURNING eid INTO _emp_id;
	
	IF (_status = 'part_time') THEN
		INSERT INTO Part_time_Emp VALUES(_emp_id, _salary, _status);
	END IF;
	IF (_status = 'full_time') THEN
		INSERT INTO Full_time_Emp VALUES(_emp_id, _salary, _status);
	END IF;
	IF (_category = 'administrator') THEN
		INSERT INTO Administrators VALUES(_emp_id, _job_type);
	END IF;
	IF (_category = 'manager') THEN
		INSERT INTO Managers VALUES(_emp_id, _job_type);
		FOREACH _area IN ARRAY _course_areas
		LOOP
			INSERT INTO Course_areas VALUES(_area, _emp_id);
		END LOOP;
	END IF;
	IF (_category = 'instructor') THEN
		INSERT INTO Instructors VALUES(_emp_id, _job_type);
		/* insert back if have different tables again
		IF (_status = 'part_time') THEN
			INSERT INTO Part_time_instructors VALUES(_emp_id, _job_type);
		END IF;
		IF (_status = 'full_time') THEN
			INSERT INTO Full_time_instructors VALUES(_emp_id, _job_type);
		END IF;
		*/
		FOREACH _area IN ARRAY _course_areas
		LOOP
			INSERT INTO Specializes VALUES(_emp_id, _area);
		END LOOP;
	END IF;
END;
$$ LANGUAGE plpgsql;

-- 2
/* This routine is used to update an employee’s departed date a non-null value. The inputs to the routine is an employee identifier and a departure date. The update operation is rejected if any one of the following conditions hold: (1) the employee is an administrator who is handling some course offering where its registration deadline is after the employee’s departure date; (2) the employee is an instructor who is teaching some course session that starts after the employee’s departure date; or (3) the employee is a manager who is managing some area. */
CREATE OR REPLACE PROCEDURE remove_employee(_emp_id int, _depart_date date) AS $$
DECLARE
	_job_type text;
BEGIN
	IF (NOT does_employee_exist(_emp_id)) THEN
		RAISE EXCEPTION 'Specified employee does not exist.';
	END IF;

	SELECT job_type INTO _job_type 
	FROM Employees 
	WHERE eid = _emp_id;
	
	IF (_job_type = 'administrator' AND EXISTS(
		SELECT 1 
		FROM Offerings 
		WHERE handler = _emp_id 
			AND registration_deadline > _depart_date
	)) THEN
		RAISE EXCEPTION 'Administrator is handling some course offering where its registration deadline is after his departure date.';
	END IF;
	IF ((_job_type = 'full_time_instructor' OR _job_type = 'part_time_instructor') AND EXISTS(
		SELECT 1
		FROM Sessions
		WHERE instructor = _emp_id 
			AND date > _depart_date
	)) THEN
		RAISE EXCEPTION 'Instructor is teaching some course session that starts after his departure date.';
	END IF;
	IF (_job_type = 'manager' AND EXISTS(
		SELECT 1
		FROM Course_areas
		WHERE manager = _emp_id
	)) THEN
		RAISE EXCEPTION 'Manager is managing some course area.';
	END IF;
	
	UPDATE Employees 
	SET depart_date = _depart_date
	WHERE eid = _emp_id;
END;
$$ LANGUAGE plpgsql;

-- 3
/* This routine is used to add a new customer. The inputs to the routine include the following: name, home address, contact number, email address, and credit card details (credit card number, expiry date, CVV code). The customer identifier is generated by the system. */
CREATE OR REPLACE PROCEDURE add_customer(_name text, _address text, _phone text, _email text, _cc_num text, _expiry_date date, _cvv text) AS $$
DECLARE
	_cust_id int;
BEGIN
	INSERT INTO Customers(address, phone, name, email)
	VALUES(_address, _phone, _name, _email)
	RETURNING cust_id INTO _cust_id;
	
	INSERT INTO Credit_cards 
	VALUES(_cc_num, _cvv, _cust_id, LOCALTIMESTAMP, _expiry_date);
END;
$$ LANGUAGE plpgsql;

-- 4
/* This routine is used when a customer requests to change his/her credit card details. The inputs to the routine include the customer identifier and his/her new credit card details (credit card number, expiry date, CVV code). */
CREATE OR REPLACE PROCEDURE update_credit_card(_cust_id int, _cc_num text, _expiry_date date, _cvv text) AS $$
BEGIN
	IF (NOT does_customer_exist(_cust_id)) THEN
		RAISE EXCEPTION 'Specified customer does not exist.';
	END IF;

	INSERT INTO Credit_cards
	VALUES(_cc_num, _cvv, _cust_id, LOCALTIMESTAMP, _expiry_date);
END;
$$ LANGUAGE plpgsql;

-- 5
/* This routine is used to add a new course. The inputs to the routine include the following: course title, course description, course area, and duration. The course identifier is generated by the system. */
CREATE OR REPLACE PROCEDURE add_course(_title text, _description text, _area text, _duration int) AS $$
BEGIN
	INSERT INTO Courses(title, description, duration, area)
	VALUES(_title, _description, _duration, _area);
END;
$$ LANGUAGE plpgsql;

--6
/* This routine is used to find all the instructors who could be assigned to teach a course session. The inputs to the routine include the following: course identifier, session date, and session start hour. The routine returns a table of records consisting of employee identifier and name. */
CREATE OR REPLACE FUNCTION find_instructors(_course_id int, _session_date date, _session_start_time int) 
RETURNS TABLE(emp_id int, name text) AS $$
DECLARE
	_emp_curs CURSOR FOR (
		SELECT I.eid, E.name, I.job_type
		FROM Instructors I
		JOIN Employees E ON I.eid = E.eid
		JOIN Specializes SP ON I.eid = SP.eid 
		JOIN Courses C ON SP.name = C.area
		WHERE E.depart_date IS NULL
			AND C.course_id = _course_id
	);
	_course_duration int;
	_emp record;
BEGIN
	IF (NOT does_course_exist(_course_id)) THEN
		RAISE EXCEPTION 'Specified course does not exist.';
	END IF;

	SELECT duration INTO _course_duration
	FROM Courses 
	WHERE course_id = _course_id;
	
	IF (NOT (is_session_legal(_session_date) AND is_session_legal(_session_start_time, _course_duration))) THEN
		RAISE EXCEPTION 'Specified session is illegal.';
	END IF;

	OPEN _emp_curs;
	LOOP
		FETCH _emp_curs INTO _emp;
		EXIT WHEN NOT FOUND;
		
		CONTINUE WHEN (_emp.job_type = 'part_time_instructor' AND does_session_exceed_part_time_hours(_emp.eid, _session_date, _course_duration));
		
		IF (is_instructor_session_allowed(_emp.eid, _session_date, _session_start_time, _course_duration)) THEN
			emp_id := _emp.eid;
			name := _emp.name;
			RETURN NEXT;
		END IF;
	END LOOP;
	CLOSE _emp_curs;
END;
$$ LANGUAGE plpgsql;

--7
/* This routine is used to retrieve the availability information of instructors who could be assigned to teach a specified course. The inputs to the routine include the following: course identifier, start date, and end date. The routine returns a table of records consisting of the following information: employee identifier, name, total number of teaching hours that the instructor has been assigned for this month, day (which is within the input date range [start date, end date]), and an array of the available hours for the instructor on the specified day. The output is sorted in ascending order of employee identifier and day, and the array entries are sorted in ascending order of hour. 
Available hours refer to the possible start times of the course session.
Available hours exclude those during which sessions cannot be held. */
CREATE OR REPLACE FUNCTION get_available_instructors(_course_id int, _start_date date, _end_date date) 
RETURNS TABLE(emp_id int, name text, month_hours int, avail_day date, avail_hours int[]) AS $$
DECLARE
	_emp_curs CURSOR FOR (
		SELECT I.eid, E.name, I.job_type
		FROM Instructors I
		JOIN Employees E ON I.eid = E.eid
		JOIN Specializes SP ON I.eid = SP.eid 
		JOIN Courses C ON SP.name = C.area
		WHERE E.depart_date IS NULL 
			AND C.course_id = _course_id
		ORDER BY eid
	);
	_course_duration int;
	_month_hours int;
	_avail_hours int[];
	_emp record;
	_date date;
	_hour int;
BEGIN
	IF (NOT does_course_exist(_course_id)) THEN
		RAISE EXCEPTION 'Specified course does not exist.';
	END IF;

	SELECT duration INTO _course_duration
	FROM Courses 
	WHERE course_id = _course_id;

	OPEN _emp_curs;
	LOOP
		FETCH _emp_curs INTO _emp;
		EXIT WHEN NOT FOUND;

		_date := _start_date;
		WHILE (_date <= _end_date) LOOP
			IF (is_session_legal(_date)) THEN
				_month_hours := get_instructor_month_hours(_emp.eid, EXTRACT(year FROM _date)::int, EXTRACT(month FROM _date)::int);
				
				IF (NOT (_emp.job_type = 'part_time_instructor' AND (_month_hours + _course_duration > 30))) THEN
					_avail_hours := ARRAY[]::int[];
					_hour := 9;
					WHILE (_hour < 18) LOOP
						IF (is_session_legal(_hour, _course_duration) AND is_instructor_session_allowed(_emp.eid, _date, _hour, _course_duration)) THEN
							_avail_hours := array_append(_avail_hours, _hour);
						END IF;
						
						_hour := _hour + 1;
					END LOOP;
					
					IF (cardinality(_avail_hours) > 0) THEN
						emp_id := _emp.eid;
						name := _emp.name;
						month_hours := _month_hours;
						avail_day := _date;
						avail_hours := _avail_hours;
						RETURN NEXT;
					END IF;
				END IF;
			END IF;
			
			_date := _date + INTERVAL '1 day';
		END LOOP;
	END LOOP;
	CLOSE _emp_curs;
END;
$$ LANGUAGE plpgsql;

--8
/* This routine is used to find all the rooms that could be used for a course session. The inputs to the routine include the following: session date, session start hour, and session duration. The routine returns a table of room identifiers. */
CREATE OR REPLACE FUNCTION find_rooms(_session_date date, _session_start_time int, _session_duration int) 
RETURNS TABLE(room_id int) AS $$
BEGIN
	IF (NOT (is_session_legal(_session_date) AND is_session_legal(_session_start_time, _session_duration))) THEN
		RAISE EXCEPTION 'Specified session is illegal.';
	END IF;
	
	RETURN QUERY
	SELECT rid
	FROM Rooms
	WHERE is_session_allowed(rid, _session_date, _session_start_time, _session_duration);
END;
$$ LANGUAGE plpgsql;

--9
/* This routine is used to retrieve the availability information of rooms for a specific duration. The inputs to the routine include a start date and an end date. The routine returns a table of records consisting of the following information: room identifier, room capacity, day (which is within the input date range [start date, end date]), and an array of the hours that the room is available on the specified day. The output is sorted in ascending order of room identifier and day, and the array entries are sorted in ascending order of hour. 
Available hours refer to the possible start times of the shortest possible course session (1 hour).
Available hours exclude those during which sessions cannot be held. */
CREATE OR REPLACE FUNCTION get_available_rooms(_start_date date, _end_date date) 
RETURNS TABLE(room_id int, room_capacity int, avail_day date, avail_hours int[]) AS $$
DECLARE
	_room_curs CURSOR FOR (SELECT * FROM Rooms);
	_avail_hours int[];
	_room record;
	_date date;
	_hour int;
BEGIN
	OPEN _room_curs;
	LOOP
		FETCH _room_curs INTO _room;
		EXIT WHEN NOT FOUND;
		
		_date := _start_date;
		WHILE (_date <= _end_date) LOOP
			IF (is_session_legal(_date)) THEN
				_avail_hours := ARRAY[]::int[];
				_hour := 9;
				WHILE (_hour < 18) LOOP
					IF (is_session_legal(_hour, 1) AND is_session_allowed(_room.rid, _date, _hour, 1)) THEN
						_avail_hours := array_append(_avail_hours, _hour);
					END IF;
					
					_hour := _hour + 1;
				END LOOP;
				
				IF (cardinality(_avail_hours) > 0) THEN
					room_id := _room.rid;
					room_capacity := _room.seating_capacity;
					avail_day := _date;
					avail_hours := _avail_hours;
					RETURN NEXT;
				END IF;
			END IF;
			
			_date := _date + INTERVAL '1 day';
		END LOOP;
	END LOOP;
	CLOSE _room_curs;
END;
$$ LANGUAGE plpgsql;

-- 10
/* This routine is used to add a new offering of an existing course. The inputs to the routine include the following: course offering identifier, course identifier, course fees, launch date, registration deadline, administrator’s identifier, and information for each session (session date, session start hour, and room identifier). If the input course offering information is valid, the routine will assign instructors for the sessions. If a valid instructor assignment exists, the routine will perform the necessary updates to add the course offering; otherwise, the routine will abort the course offering addition. Note that the seating capacity of the course offering must be at least equal to the course offering’s target number of registrations. */
CREATE OR REPLACE PROCEDURE add_course_offering(_offering_id int, _course_id int, _course_fees int, _target_reg int, _launch_date date, _reg_deadline date, _admin_id int, _sessions session_info[]) AS $$
DECLARE
	_instr_id int;
	_session_num int;
	_session session_info;
BEGIN
	IF (NOT does_course_exist(_course_id)) THEN
		RAISE EXCEPTION 'Specified course does not exist.';
	END IF;
	IF (NOT does_administrator_exist(_admin_id)) THEN
		RAISE EXCEPTION 'Specified administrator does not exist.';
	END IF;

	IF _target_reg > get_offering_seating_capacity(_offering_id) THEN
		RAISE EXCEPTION 'Target registration exceeds course offering seating capacity.';
	END IF;
	IF cardinality(_sessions) <= 0 THEN
		RAISE EXCEPTION 'A course offering must have at least 1 session!';
	END IF;
	_session_num := 1;
	-- Insert into Offerings first so foreign key exists for Sessions
	INSERT INTO Offerings(offering_id, course_id, launch_date, fees, target_number_registrations, registration_deadline, handler)
	VALUES(_offering_id, _course_id, _launch_date, _course_fees, _target_reg, _reg_deadline, _admin_id);
	FOREACH _session IN ARRAY _sessions LOOP
		IF (NOT does_room_exist(_session.room_id)) THEN
			RAISE EXCEPTION 'One of the specified rooms does not exist.';
		END IF;
		IF NOT EXISTS (
			SELECT 1
			FROM find_instructors(_course_id, _session.date, _session.start_time)
		) THEN
			RAISE EXCEPTION 'No instructor available to teach 1 of the sessions!';
		END IF;
		SELECT emp_id INTO _instr_id
		FROM find_instructors(_course_id, _session.date, _session.start_time)
		LIMIT 1;
		CALL add_session(_offering_id, _session_num, _session.date, _session.start_time, _instr_id, _session.room_id);
		_session_num := _session_num + 1;
	END LOOP;
END;
$$ LANGUAGE plpgsql;

--11
/* This routine is used to add a new course package for sale. The inputs to the routine include the following: package name, number of free course sessions, start and end date indicating the duration that the promotional package is available for sale, and the price of the package. The course package identifier is generated by the system. If the course package information is valid, the routine will perform the necessary updates to add the new course package. */
CREATE OR REPLACE PROCEDURE add_course_package(_name text, _num_free_sessions int, _sale_start_date date, _sale_end_date date, _price int) AS $$
BEGIN
	INSERT INTO Course_packages(sale_start_date, sale_end_date, num_free_registrations, name, price)
	VALUES(_sale_start_date, _sale_end_date, _num_free_sessions, _name, _price);
END;
$$ LANGUAGE plpgsql;

--12
/* This routine is used to retrieve the course packages that are available for sale. The routine returns a table of records with the following information for each available course package: package name, number of free course sessions, end date for promotional package, and the price of the package. */
DROP FUNCTION IF EXISTS get_available_course_packages();
CREATE OR REPLACE FUNCTION get_available_course_packages() 
RETURNS TABLE(name text, num_free_sessions int, sale_end_date date, price int, package_id int) AS $$
DECLARE
	_curr_date date;
BEGIN
	_curr_date := CURRENT_DATE;
	RETURN QUERY
	SELECT P.name, P.num_free_registrations, P.sale_end_date, P.price, P.package_id
	FROM Course_packages P
	WHERE _curr_date > P.sale_start_date and _curr_date < P.sale_end_date;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_package_if_available_for_purchase(IN _package_id int, OUT name text, OUT num_free_registrations int, OUT sale_end_date date, OUT price int) 
RETURNS record AS $$
	SELECT P.name, P.num_free_sessions AS num_free_registrations, P.sale_end_date, P.price
	FROM get_available_course_packages() P
	WHERE P.package_id = _package_id;
$$ LANGUAGE sql;

--13
/* This routine is used when a customer requests to purchase a course package. The inputs to the routine include the customer and course package identifiers. If the purchase transaction is valid, the routine will process the purchase with the necessary updates (e.g., payment). */
CREATE OR REPLACE PROCEDURE buy_course_package(_cust_id int, _package_id int) AS $$
DECLARE
	_credit_card_r record;
	r record;
BEGIN
	IF (NOT does_customer_exist(_cust_id)) THEN
		RAISE EXCEPTION 'Specified customer does not exist.';
	END IF;
	r := get_package_if_available_for_purchase(_package_id);
	IF r IS NULL THEN
		RAISE EXCEPTION 'Package is not available for purchase!';
	END IF;
	_credit_card_r := get_latest_credit_card(_cust_id);
	INSERT INTO Buys(date, package_id, number, num_remaining_redemptions)
	VALUES(CURRENT_TIMESTAMP, _package_id, _credit_card_r.number, r.num_free_registrations);
END;
$$ LANGUAGE plpgsql;

--14
/* This routine is used when a customer requests to view his/her active/partially active course package. The input to the routine is a customer identifier. The routine returns the following information as a JSON value: package name, purchase date, price of package, number of free sessions included in the package, number of sessions that have not been redeemed, and information for each redeemed session (course name, session date, session start hour). The redeemed session information is sorted in ascending order of session date and start hour. */
CREATE OR REPLACE FUNCTION get_my_course_package(_cust_id int) 
RETURNS json AS $$
DECLARE
	_cc_num varchar(19);
	r record;
	_package record;
	_session_info redeemed_session_info[];
	_pkg_info course_package_info;
	_most_recent_session_date date;
	_curr_date date;
BEGIN
	IF (NOT does_customer_exist(_cust_id)) THEN
		RAISE EXCEPTION 'Specified customer does not exist.';
	END IF;
	r := get_latest_course_package(_cust_id);
	IF r IS NULL THEN
		RAISE EXCEPTION 'Customer has not bought a package before.';
	END IF;
	SELECT * INTO _package
	FROM Course_packages P
	WHERE P.package_id = r.package_id;
	IF r.num_remaining_redemptions >= 1 THEN
		-- Active package
		_session_info := get_redeemed_sessions(r.date, r.package_id, r.number);
		_pkg_info := ROW(_package.name , r.date, _package.price, _package.num_free_registrations, r.num_remaining_redemptions, _session_info);
		RETURN to_json(_pkg_info);
	ELSE
		-- All sessions have been redeemed
		SELECT S.date INTO _most_recent_session_date
		FROM Redeems Re JOIN Sessions S ON Re.sid = S.sid AND Re.offering_id = S.offering_id
		WHERE Re.buys_date = r.date AND package_id = r.package_id AND number = r.number
		ORDER BY S.date desc;
		-- Check if package is partially active (one session at least 7 days later)
		_curr_date = CURRENT_DATE;
		IF NOT _curr_date + 7 > _most_recent_session_date THEN
			-- Partially active!
			_session_info := get_redeemed_sessions(r.date, r.package_id, r.number);
			_pkg_info := ROW(_package.name , r.date, _package.price, _package.num_free_registrations, r.num_remaining_redemptions, _session_info);
			RETURN to_json(_pkg_info);
		END IF;
		-- Package is inactive
		RAISE EXCEPTION 'Customer has an inactive package!';
	END IF;
END;
$$ LANGUAGE plpgsql;

--15
/* This routine is used to retrieve all the available course offerings that could be registered. The routine returns a table of records with the following information for each course offering: course title, course area, start date, end date, registration deadline, course fees, and the number of remaining seats. The output is sorted in ascending order of registration deadline and course title. */
CREATE OR REPLACE FUNCTION get_available_course_offerings() 
RETURNS TABLE(course_title text, course_area text, start_date date, end_date date, reg_deadline date, course_fees int, num_rem_seats int) AS $$
DECLARE
	_curr_date date;
BEGIN
	SELECT CURRENT_DATE INTO _curr_date;
	RETURN QUERY
	SELECT * 
	FROM get_unsorted_available_course_offerings(_curr_date) O
	ORDER BY O.reg_deadline, O.course_title;
END;
$$ LANGUAGE plpgsql;

--16
/* This routine is used to retrieve all the available sessions for a course offering that could be registered. The input to the routine is a course offering identifier. The routine returns a table of records with the following information for each available session: session date, session start hour, instructor name, and number of remaining seats for that session. The output is sorted in ascending order of session date and start hour. */
CREATE OR REPLACE FUNCTION get_available_course_sessions(_offering_id int) 
RETURNS TABLE(session_date date, session_start_time int, instructor_name text, num_rem_seats int) AS $$
BEGIN
	IF (NOT does_offering_exist(_offering_id)) THEN
		RAISE EXCEPTION 'Specified course offering does not exist.';
	END IF;

	RETURN QUERY
	SELECT CS.date, CS.start_time, E.name, (R.seating_capacity - get_session_num_registrations(_offering_id, CS.sid))::int
	FROM CourseOfferingSessions CS 
	JOIN Employees E ON CS.instructor = E.eid
	JOIN Rooms R ON CS.room = R.rid
	WHERE CS.offering_id = _offering_id 
		AND CS.registration_deadline >= CURRENT_DATE
		AND (R.seating_capacity - get_session_num_registrations(_offering_id, CS.sid)) > 0
	ORDER BY CS.date, CS.start_time;
END;
$$ LANGUAGE plpgsql;

--17
/* This routine is used when a customer requests to register for a session in a course offering. The inputs to the routine include the following: customer identifier, course offering identifier, session number, and payment method (credit card or redemption from active package). If the registration transaction is valid, this routine will process the registration with the necessary updates (e.g., payment/redemption). */
CREATE OR REPLACE PROCEDURE register_session(_cust_id int, _offering_id int, _session_id int, _pay_by payment_method) AS $$
DECLARE
	_credit_card record;
	_buys_package record;
	_reg_deadline date;
BEGIN
	IF (NOT does_customer_exist(_cust_id)) THEN
		RAISE EXCEPTION 'Specified customer does not exist.';
	END IF;
	IF (NOT does_offering_exist(_offering_id)) THEN
		RAISE EXCEPTION 'Specified course offering does not exist.';
	END IF;
	IF (NOT does_session_exist(_offering_id, _session_id)) THEN
		RAISE EXCEPTION 'Specified course session does not exist.';
	END IF;

	SELECT registration_deadline INTO _reg_deadline
	FROM Offerings 
	WHERE offering_id = _offering_id;
	
	IF (_reg_deadline < CURRENT_DATE) THEN
		RAISE EXCEPTION 'Registration deadline for course offering is over.';
	END IF;
	IF (is_registered_for_offering(_cust_id, _offering_id)) THEN
		RAISE EXCEPTION 'Already registered for specified course offering.';
	END IF;
	IF (NOT is_session_available(_offering_id, _session_id)) THEN
		RAISE EXCEPTION 'No available seats for specified course session';
	END IF;
	
	IF (_pay_by = 'credit_card') THEN
		_credit_card := get_latest_credit_card(_cust_id);
		
		IF (_credit_card.expiry_date < CURRENT_DATE) THEN
			RAISE EXCEPTION 'Credit card has expired.';
		END IF;
		
		INSERT INTO Registers
		VALUES(LOCALTIMESTAMP, _credit_card.number, _session_id, _offering_id);
	END IF;
	IF (_pay_by = 'course_package') THEN
		_buys_package := get_latest_course_package(_cust_id);
	
		IF (_buys_package IS NULL) THEN
			RAISE EXCEPTION 'No course package bought.';
		END IF;
		IF (_buys_package.num_remaining_redemptions <= 0) THEN
			RAISE EXCEPTION 'Course package fully redeemed.';
		END IF;
		
		INSERT INTO Redeems
		VALUES(_buys_package.date, _buys_package.package_id, _buys_package.number, LOCALTIMESTAMP, _session_id, _offering_id);
		
		UPDATE Buys
		SET num_remaining_redemptions = num_remaining_redemptions - 1
		WHERE date = _buys_package.date
			AND package_id = _buys_package.package_id
			AND number = _buys_package.number;
	END IF;
END;
$$ LANGUAGE plpgsql;

--18
/* This routine is used when a customer requests to view his/her active course registrations (i.e, registrations for course sessions that have not ended). The input to the routine is a customer identifier. The routine returns a table of records with the following information for each active registration session: course name, course fees, session date, session start hour, session duration, and instructor name. The output is sorted in ascending order of session date and session start hour. */
CREATE OR REPLACE FUNCTION get_my_registrations(_cust_id int) 
RETURNS TABLE(course_name text, course_fees int, session_date date, session_start_time int, session_duration int, instructor_name text) AS $$
BEGIN
	IF (NOT does_customer_exist(_cust_id)) THEN
		RAISE EXCEPTION 'Specified customer does not exist.';
	END IF;
	
	RETURN QUERY
	SELECT CS.title, CS.fees, CS.date, CS.start_time, CS.duration, E.name
	FROM CourseOfferingSessions CS JOIN Employees E ON CS.instructor = E.eid
	WHERE (CS.date > CURRENT_DATE OR (CS.date = CURRENT_DATE AND CS.start_time + CS.duration > EXTRACT(HOUR FROM LOCALTIME))) 
		AND is_registered_for_session(_cust_id, CS.offering_id, CS.sid);
END;
$$ LANGUAGE plpgsql;

--19
/* This routine is used when a customer requests to change a registered course session to another session. The inputs to the routine include the following: customer identifier, course offering identifier, and new session number. If the update request is valid and there is an available seat in the new session, the routine will process the request with the necessary updates. 
Cannot update from and to a session that has already started.
Does not update the registration or redemption date. */
CREATE OR REPLACE PROCEDURE update_course_session(_cust_id int, _offering_id int, _new_session_id int) AS $$
DECLARE
	_old_session record;
BEGIN
	IF (NOT does_customer_exist(_cust_id)) THEN
		RAISE EXCEPTION 'Specified customer does not exist.';
	END IF;
	IF (NOT does_offering_exist(_offering_id)) THEN
		RAISE EXCEPTION 'Specified course offering does not exist.';
	END IF;
	IF (NOT does_session_exist(_offering_id, _new_session_id)) THEN
		RAISE EXCEPTION 'Specified course session does not exist.';
	END IF;

	_old_session = get_registered_session(_cust_id, _offering_id);
	
	IF (_old_session IS NULL) THEN
		RAISE EXCEPTION 'Not registered for specified course offering.';
	END IF;
	IF (_old_session.sid = _new_session_id) THEN
		RAISE EXCEPTION 'Already registered for specified course session.';
	END IF;
	IF (get_session_timestamp(_offering_id, _old_session_id) < LOCALTIMESTAMP) THEN
		RAISE EXCEPTION 'Current course session has already started.';
	END IF;
	IF (get_session_timestamp(_offering_id, _new_session_id) < LOCALTIMESTAMP) THEN
		RAISE EXCEPTION 'Specified course session has already started.';
	END IF;
	IF (NOT is_session_available(_offering_id, _new_session_id)) THEN
		RAISE EXCEPTION 'No available seats for specified course session.';
	END IF;
	
	IF (_old_session.paid_by = 'credit_card') THEN
		UPDATE Registers
		SET sid = _new_session_id
		WHERE date = _old_session.paid_date
			AND number = _old_session.cc_num
			AND sid = _old_session.session_id
			AND offering_id = _offering_id;
	END IF;
	IF (_old_session.paid_by = 'course_package') THEN
		UPDATE Redeems
		SET sid = _new_session_id
		WHERE buys_date = _old_session.package_buys_date
			AND package_id = _old_session.course_package_id
			AND number = _old_session.cc_num
			AND date = _old_session.paid_date
			AND sid = _old_session.session_id
			AND offering_id = _offering_id;
	END IF;
END;
$$ LANGUAGE plpgsql;

--20
/* This routine is used when a customer requests to cancel a registered course session. The inputs to the routine include the following: customer identifier, and course offering identifier. If the cancellation request is valid, the routine will process the request with the necessary updates. */
CREATE OR REPLACE PROCEDURE cancel_registration(_cust_id int, _offering_id int) AS $$
DECLARE
	_session record;
	_session_start timestamp;
	_within_grace_period boolean;
	_refund_amount int;
	_package_credit int;
BEGIN
	IF (NOT does_customer_exist(_cust_id)) THEN
		RAISE EXCEPTION 'Specified customer does not exist.';
	END IF;
	IF (NOT does_offering_exist(_offering_id)) THEN
		RAISE EXCEPTION 'Specified course offering does not exist.';
	END IF;

	_session := get_registered_session(_cust_id, _offering_id);
	_session_start := get_session_timestamp(_offering_id, _session.session_id);
	
	IF (_session IS NULL) THEN
		RAISE EXCEPTION 'Not registered for specified course offering.';
	END IF;
	IF (_session_start < LOCALTIMESTAMP) THEN
		RAISE EXCEPTION 'Current course session has already started.';
	END IF;
	
	_within_grace_period := (_session_start::date - CURRENT_DATE) >= 7;
	IF (_session.paid_by = 'credit_card') THEN
		IF (_within_grace_period) THEN
			SELECT 0.9*fees INTO _refund_amount
			FROM Offerings
			WHERE offering_id = _offering_id;
		ELSE 
			_refund_amount := 0;
		END IF;
	END IF;
	IF (_session.paid_by = 'course_package') THEN
		IF (_within_grace_period) THEN
			_package_credit := 1;
			
			UPDATE Buys
			SET num_remaining_redemptions = num_remaining_redemptions + _package_credit
			WHERE date = _session.package_buys_date
				AND package_id = _session.course_package_id
				AND number = _session.cc_num;
		ELSE 
			_package_credit := 0;
		END IF;
	END IF;	
	
	INSERT INTO Cancels
	VALUES(_cust_id, LOCALTIMESTAMP, _session.session_id, _offering_id, _refund_amount, _package_credit);
END;
$$ LANGUAGE plpgsql;

--21
/* This routine is used to change the instructor for a course session. The inputs to the routine include the following: course offering identifier, session number, and identifier of the new instructor. If the course session has not yet started and the update request is valid, the routine will process the request with the necessary updates. */
CREATE OR REPLACE PROCEDURE update_instructor(_offering_id int, _session_id int, _new_instructor_id int) AS $$
DECLARE
	_old_instructor_id int;
	_new_instructor record;
	_session_date date;
	_session_start int;
	_course_duration int;
	_course_area text;
BEGIN
	IF (NOT does_offering_exist(_offering_id)) THEN
		RAISE EXCEPTION 'Specified course offering does not exist.';
	END IF;
	IF (NOT does_session_exist(_offering_id, _session_id)) THEN
		RAISE EXCEPTION 'Specified course session does not exist.';
	END IF;
	IF (NOT does_employee_exist(_new_instructor_id)) THEN
		RAISE EXCEPTION 'Specified employee does not exist.';
	END IF;
	IF (NOT does_instructor_exist(_new_instructor_id)) THEN
		RAISE EXCEPTION 'Specified employee is not an instructor.';
	END IF;
	
	IF (get_session_timestamp(_offering_id, _session_id) < LOCALTIMESTAMP) THEN
		RAISE EXCEPTION 'Specified course session has already started.';
	END IF;
	
	SELECT instructor INTO _old_instructor_id
	FROM Sessions
	WHERE offering_id = _offering_id 
		AND sid = _session_id;
		
	IF (_new_instructor_id = _old_instructor_id) THEN
		RAISE EXCEPTION 'Specified instructor is same as current instructor.';
	END IF;
	
	SELECT * INTO _new_instructor
	FROM Employees
	WHERE eid = _new_instructor_id;
	
	SELECT date, start_time, duration, area INTO _session_date, _session_start, _course_duration, _course_area
	FROM CourseOfferingSessions
	WHERE offering_id = _offering_id
		AND sid = _session_id;
		
	IF (_new_instructor.depart_date IS NOT NULL) THEN
		RAISE EXCEPTION 'Specified instructor has already departed.';
	END IF;
	IF (SELECT NOT EXISTS(
		SELECT 1
		FROM Specializes
		WHERE eid = _new_instructor_id
			AND name = _course_area
	)) THEN
		RAISE EXCEPTION 'Specified instructor does not specialize in course area of specified course session.';
	END IF;
	IF (_new_instructor.job_type = 'part_time_instructor' AND does_session_exceed_part_time_hours(_new_instructor_id, _session_date, _course_duration)) THEN
		RAISE EXCEPTION 'Specified instructor will exceed maximum part-time hours.';
	END IF;
	IF (NOT is_instructor_session_allowed(_new_instructor_id, _session_date, _session_start, _course_duration)) THEN
		RAISE EXCEPTION 'Specified course session clashes with another session conducted by specified instructor.';
	END IF;
	
	UPDATE Sessions
	SET instructor = _new_instructor_id
	WHERE offering_id = _offering_id
		AND sid = _session_id;
END;
$$ LANGUAGE plpgsql;

--22
/* This routine is used to change the room for a course session. The inputs to the routine include the following: course offering identifier, session number, and identifier of the new room. If the course session has not yet started and the update request is valid, the routine will process the request with the necessary updates. Note that update request should not be performed if the number of registrations for the session exceeds the seating capacity of the new room. */
CREATE OR REPLACE PROCEDURE update_room(_offering_id int, _session_id int, _new_room_id int) AS $$
DECLARE
	_old_room_id int;
	_new_capacity int;
	_session_date date;
	_session_start int;
	_course_duration int;
BEGIN
	IF (NOT does_offering_exist(_offering_id)) THEN
		RAISE EXCEPTION 'Specified course offering does not exist.';
	END IF;
	IF (NOT does_session_exist(_offering_id, _session_id)) THEN
		RAISE EXCEPTION 'Specified course session does not exist.';
	END IF;
	IF (NOT does_room_exist(_new_room_id)) THEN
		RAISE EXCEPTION 'Specified room does not exist.';
	END IF;
	
	IF (get_session_timestamp(_offering_id, _session_id) < LOCALTIMESTAMP) THEN
		RAISE EXCEPTION 'Specified course session has already started.';
	END IF;
	
	SELECT room INTO _old_room_id
	FROM Sessions
	WHERE offering_id = _offering_id 
		AND sid = _session_id;
		
	IF (_new_room_id = _old_room_id) THEN
		RAISE EXCEPTION 'Specified room is same as current room.';
	END IF;
	
	SELECT seating_capacity INTO _new_capacity
	FROM Rooms
	WHERE rid = _new_room_id;
	
	IF (get_session_num_registrations(_offering_id, _session_id) > _new_capacity) THEN
		RAISE EXCEPTION 'Number of registrations for specified course session exceeds seating capacity of specified room.';
	END IF;
	
	SELECT date, start_time, duration INTO _session_date, _session_start, _course_duration
	FROM CourseOfferingSessions
	WHERE offering_id = _offering_id 
		AND sid = _session_id;
		
	IF (NOT is_session_allowed(_new_room_id, _session_date, _session_start, _course_duration)) THEN
		RAISE EXCEPTION 'Specified course session clashes with another session held in specified room.';
	END IF;
	
	UPDATE Sessions
	SET room = _new_room_id
	WHERE offering_id = _offering_id
		AND sid = _session_id;
END;
$$ LANGUAGE plpgsql;

--23
/* This routine is used to remove a course session. The inputs to the routine include the following: course offering identifier and session number. If the course session has not yet started and the request is valid, the routine will process the request with the necessary updates. The request must not be performed if there is at least one registration for the session. Note that the resultant seating capacity of the course offering could fall below the course offering’s target number of registrations, which is allowed. */
CREATE OR REPLACE PROCEDURE remove_session(_offering_id int, _session_id int) AS $$
BEGIN
	IF (NOT does_offering_exist(_offering_id)) THEN
		RAISE EXCEPTION 'Specified course offering does not exist.';
	END IF;
	IF (NOT does_session_exist(_offering_id, _session_id)) THEN
		RAISE EXCEPTION 'Specified course session does not exist.';
	END IF;
	IF (get_session_num_registrations(_offering_id, _session_id) > 0) THEN
		RAISE EXCEPTION 'There is at least one registration for the specified course session.';
	END IF;
	
	DELETE FROM Sessions
	WHERE offering_id = _offering_id
		AND sid = _session_id;
END;
$$ LANGUAGE plpgsql;

--24
/* This routine is used to add a new session to a course offering. The inputs to the routine include the following: course offering identifier, new session number, new session day, new session start hour, instructor identifier for new session, and room identifier for new session. If the course offering’s registration deadline has not passed and the the addition request is valid, the routine will process the request with the necessary updates. */
CREATE OR REPLACE PROCEDURE add_session(_offering_id int, _session_id int, _date date, _start_time int, _instructor_id int, _room_id int) AS $$
DECLARE
	_instructor record;
BEGIN
	IF (NOT does_offering_exist(_offering_id)) THEN
		RAISE EXCEPTION 'Specified offering does not exist.';
	END IF;
	IF (NOT does_instructor_exist(_instructor_id)) THEN
		RAISE EXCEPTION 'Specified instructor does not exist.';
	END IF;
	IF (NOT does_room_exist(_room_id)) THEN
		RAISE EXCEPTION 'Specified room does not exist.';
	END IF;
	IF offering_reg_deadline_passed(_offering_id, _date) THEN
		RAISE EXCEPTION 'Course offering registration deadline has passed, unable to add session.';
	END IF;
	
	SELECT * INTO _instructor
	FROM Employees
	WHERE eid = _instructor_id;
	
	IF (_instructor.depart_date IS NOT NULL) THEN
		RAISE EXCEPTION 'Specified instructor has already departed.';
	END IF;
	
	INSERT INTO Sessions(sid, offering_id, instructor, date, start_time, room)
	VALUES(_session_id, _offering_id, _instructor_id, _date, _start_time, _room_id);
END;
$$ LANGUAGE plpgsql;

--25
/* This routine is used at the end of the month to pay salaries to employees. The routine inserts the new salary payment records and returns a table of records (sorted in ascending order of employee identifier) with the following information for each employee who is paid for the month: employee identifier, name, status (either part-time or full-time), number of work days for the month, number of work hours for the month, hourly rate, monthly salary, and salary amount paid. For a part-time employees, the values for number of work days for the month and monthly salary should be null. For a full-time employees, the values for number of work hours for the month and hourly rate should be null. */
CREATE OR REPLACE FUNCTION pay_salary() 
RETURNS TABLE(emp_id int, emp_name text, emp_status employee_status, num_work_days int, num_work_hours int, hourly_rate int, monthly_salary int, amount_paid int) AS $$
DECLARE
	r record;
	_curs CURSOR FOR (
		SELECT E.eid, E.name, E.salary_type, get_work_days(E.salary_type, E.join_date, E.depart_date) AS num_work_days, get_work_hours(E.eid, E.salary_type) AS num_work_hours, P.hourly_rate, F.monthly_salary, calculate_salary(E.eid, E.salary_type, E.join_date, E.depart_date, F.monthly_salary, P.hourly_rate) AS amount_paid
		FROM Employees E NATURAL LEFT JOIN Full_time_Emp F NATURAL LEFT JOIN Part_time_Emp P
		ORDER BY E.eid
	);
	_curr_date date;
BEGIN
	SELECT CURRENT_DATE INTO _curr_date;
	OPEN _curs;
	LOOP
		FETCH _curs INTO r;
		EXIT WHEN NOT FOUND;

		INSERT INTO Pay_slips(payment_date, amount, num_work_hours, num_work_days, eid)
		VALUES(_curr_date, r.amount_paid, COALESCE(r.num_work_hours, 0), COALESCE(r.num_work_days, 0), r.eid);	

		emp_id := r.eid;
		emp_name := r.name;
		emp_status := r.salary_type;
		num_work_days := r.num_work_days;
		num_work_hours := r.num_work_hours;
		hourly_rate := r.hourly_rate;
		monthly_salary := r.monthly_salary;
		amount_paid := r.amount_paid;
		RETURN NEXT;
	END LOOP;
	CLOSE _curs;
END;
$$ LANGUAGE plpgsql;

--26
/* This routine is used to identify potential course offerings that could be of interest to inactive customers. A customer is classified as an active customer if the customer has registered for some course offering in the last six months (inclusive of the current month); otherwise, the customer is considered to be inactive customer. A course area A is of interest to a customer C if there is some course offering in area A among the three most recent course offerings registered by C. If a customer has not yet registered for any course offering, we assume that every course area is of interest to that customer. The routine returns a table of records consisting of the following information for each inactive customer: customer identifier, customer name, course area A that is of interest to the customer, course identifier of a course C in area A, course title of C, launch date of course offering of course C that still accepts registrations, course offering’s registration deadline, and fees for the course offering. The output is sorted in ascending order of customer identifier and course offering’s registration deadline. */
CREATE OR REPLACE FUNCTION promote_courses() 
RETURNS TABLE(cust_id int, cust_name text, course_area text, course_id int, course_title text, launch_date date, reg_deadline date, course_fees int) AS $$
BEGIN
	RETURN QUERY
	SELECT *
	FROM get_unsorted_courses_to_promote() C
	ORDER BY C.cust_id, C.reg_deadline;
END;
$$ LANGUAGE plpgsql;

--27
/* This routine is used to find the top N course packages in terms of the total number of packages sold for this year (i.e., the package’s start date is within this year). The input to the routine is a positive integer number N. The routine returns a table of records consisting of the following information for each of the top N course packages: package identifier, number of included free course sessions, price of package, start date, end date, and number of packages sold. The output is sorted in descending order of number of packages sold followed by descending order of price of package. In the event that there are multiple packages that tie for the top Nth position, all these packages should be included in the output records; thus, the output table could have more than N records. It is also possible for the output table to have fewer than N records if N is larger than the number of packages launched this year. */
CREATE OR REPLACE FUNCTION top_packages(_n int) 
RETURNS TABLE(package_id int, num_free_sessions int, price int, start_date date, end_date date, num_packages_sold int) AS $$
DECLARE
	_curr_year int;
	_package record;
	_n_count int;
	_index int;
BEGIN
	SELECT extract(year FROM now()) INTO _curr_year;

	RETURN QUERY
	SELECT P.package_id, P.num_free_registrations, P.price, P.sale_start_date, P.sale_end_date, count(*) 
	FROM Buys B NATURAL JOIN Course_packages P
	WHERE B.date >= make_date(_curr_year, 1, 1)
	GROUP BY P.package_id
	ORDER BY count(*) desc, P.price desc
	LIMIT _n;

	-- to check for tied packages, get packages again but offset by N, 
	--    check highest if tied, if yes, RETURN NEXT, LOOP till not tied 
	_index := _n;
	SELECT count(*) INTO _n_count
	FROM Buys B NATURAL JOIN Course_packages P
	WHERE B.date >= make_date(_curr_year, 1, 1)
	GROUP BY P.package_id
	ORDER BY count(*) desc, P.price desc
	OFFSET _n - 1
	LIMIT 1;
	LOOP
		SELECT P.package_id, P.num_free_registrations, P.price, P.sale_start_date, P.sale_end_date, count(*) AS count INTO _package
		FROM Buys B NATURAL JOIN Course_packages P
		WHERE B.date >= make_date(_curr_year, 1, 1)
		GROUP BY P.package_id
		ORDER BY count(*) desc, P.price desc
		OFFSET _index
		LIMIT 1;

		-- Only have N or less than N records
		IF _package IS NULL THEN
			EXIT;
		END IF;

		IF _package.count = _n_count THEN
			package_id := _package.package_id;
			num_free_sessions := _package.num_free_registrations;
			price := _package.price;
			start_date := _package.sale_start_date;
			end_date := _package.sale_end_date;
			num_packages_sold := _package.count;
			RETURN NEXT;
		ELSE
			EXIT;
		END IF;
		-- Increment
		_index := _index + 1;
	END LOOP;
END;
$$ LANGUAGE plpgsql;

--28
/* This routine is used to find the popular courses offered this year (i.e., start date is within this year). A course is popular if the course has at least two offerings this year, and for every pair of offerings of the course this year, the offering with the later start date has a higher number of registrations than that of the offering with the earlier start date. The routine returns a table of records consisting of the following information for each popular course: course identifier, course title, course area, number of offerings this year, and number of registrations for the latest offering this year. The output is sorted in descending order of the number of registrations for the latest offering this year followed by in ascending order of course identifier. */
CREATE OR REPLACE FUNCTION popular_courses() 
RETURNS TABLE(course_id int, course_title text, course_area text, num_offerings int, num_latest_regs int) AS $$
BEGIN
	-- Popular courses offered this year
	RETURN QUERY
	SELECT * 
	FROM get_popular_courses() C
	ORDER BY C.num_reg desc, C.course_id;
END;
$$ LANGUAGE plpgsql;

--29
/* This routine is used to view a monthly summary report of the company’s sales and expenses for a specified number of months. The input to the routine is a number of months (say N) and the routine returns a table of records consisting of the following information for each of the last N months (starting from the current month): month and year, total salary paid for the month, total amount of sales of course packages for the month, total registration fees paid via credit card payment for the month, total amount of refunded registration fees (due to cancellations) for the month, and total number of course registrations via course package redemptions for the month. For example, if the number of specified months is 3 and the current month is January 2021, the output will consist of one record for each of the following three months: January 2021, December 2020, and November 2020. */
CREATE OR REPLACE FUNCTION view_summary_report(_num_months int) 
RETURNS TABLE(year int, month int, total_salary_paid int, total_package_sales int, total_reg_fees int, total_refunded_fees int, total_redemptions int) AS $$
DECLARE
	_curr_date date;
BEGIN
	SELECT CURRENT_DATE INTO _curr_date;
	-- Loop for _num_months times
	FOR i in 1.._num_months LOOP
		SELECT extract(month FROM _curr_date) INTO month;
		SELECT extract(year FROM _curr_date) INTO year;
		SELECT sum(S.amount) INTO total_salary_paid
		FROM Pay_slips S
		WHERE extract(month FROM S.payment_date) = month
			AND extract(year FROM S.payment_date) = year;
		SELECT sum(P.price) INTO total_package_sales
		FROM Buys B NATURAL JOIN Course_packages P
		WHERE extract(month FROM B.date) = month
			AND extract(year FROM B.date) = year;
		SELECT sum(O.fees) INTO total_reg_fees
		FROM Registers R NATURAL JOIN Offerings O
		WHERE extract(month FROM R.date) = month
			AND extract(year FROM R.date) = year;
		SELECT sum(C.refund_amt) INTO total_refunded_fees
		FROM Cancels C
		WHERE extract(month FROM C.date) = month
			AND extract(year FROM C.date) = year;
		SELECT count(*) INTO total_redemptions
		FROM Redeems Re
		WHERE extract(month FROM Re.date) = month
			AND extract(year FROM Re.date) = year;
		RETURN NEXT;
		_curr_date := _curr_date - INTERVAL '1 month';
	END LOOP;
END;
$$ LANGUAGE plpgsql;

--30
/* This routine is used to view a report on the sales generated by each manager. The routine returns a table of records consisting of the following information for each manager: manager name, total number of course areas that are managed by the manager, total number of course offerings that ended this year (i.e., the course offering’s end date is within this year) that are managed by the manager, total net registration fees for all the course offerings that ended this year that are managed by the manager, the course offering title (i.e., course title) that has the highest total net registration fees among all the course offerings that ended this year that are managed by the manager; if there are ties, list all these top course offering titles. The total net registration fees for a course offering is defined to be the sum of the total registration fees paid for the course offering via credit card payment (excluding any refunded fees due to cancellations) and the total redemption registration fees for the course offering. The redemption registration fees for a course offering refers to the registration fees for a course offering that is paid via a redemption from a course package; this registration fees is given by the price of the course package divided by the number of sessions included in the course package (rounded down to the nearest dollar). There must be one output record for each manager in the company and the output is to be sorted by ascending order of manager name. */
CREATE OR REPLACE FUNCTION view_manager_report() 
RETURNS TABLE(manager_name text, total_num_areas int, total_offerings int, total_reg_fees int, highest_total_fees_offering text) AS $$
DECLARE
	_curs CURSOR FOR (
		SELECT E.name, E.eid
		FROM Managers NATURAL JOIN Employees E
	);
	_manager record;
	_total_fees_record record;
	_highest_reg_fees int;
BEGIN
	_highest_reg_fees := 0;
	OPEN _curs;
	LOOP
		FETCH _curs INTO _manager;
		EXIT WHEN NOT FOUND;
		manager_name := _manager.name;
		total_num_areas := get_num_course_areas(_manager.eid);
		total_offerings := get_num_course_offerings(_manager.eid);
		_total_fees_record := get_total_reg_fees_managed(_manager.eid);
		total_reg_fees := _total_fees_record.net_fees;
		IF _total_fees_record.net_fees > _highest_reg_fees THEN
			highest_total_fees_offering := _total_fees_record.title;
			_highest_reg_fees := _total_fees_record.net_fees;
		ELSIF _total_fees_record.net_fees = _highest_reg_fees THEN
			highest_total_fees_offering := highest_total_fees_offering || ', ' || _total_fees_record.title;
		END IF;
		RETURN NEXT;
	END LOOP;
	CLOSE _curs;
END;
$$ LANGUAGE plpgsql;
