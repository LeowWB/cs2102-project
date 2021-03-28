CREATE OR REPLACE TYPE employee_status AS ENUM ('full_time', 'part_time');
CREATE OR REPLACE TYPE employee_category AS ENUM ('administrator', 'manager', 'instructor');
CREATE OR REPLACE TYPE session_info AS (date date, start_hour int, room_id int);
CREATE OR REPLACE TYPE payment_method AS ENUM ('credit_card', 'course_package');

CREATE OR REPLACE FUNCTION get_course_duration(_course_id int) RETURNS int AS $$
BEGIN
	RETURN QUERY
	SELECT duration FROM Courses WHERE course_id = _course_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION instructor_month_hours(_emp_id int, _year int, _month int) RETURNS int AS $$
BEGIN
	RETURN QUERY
	SELECT sum(duration)
	FROM Sessions S JOIN Courses C ON S.course_id = C.course_id
	WHERE instructor = _emp_id AND EXTRACT(year FROM date) = _year AND EXTRACT(month FROM date) = _month;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ranges_overlap(_start1 int, _end1 int, _start2 int, _end2 int) RETURNS BOOLEAN AS $$
BEGIN
	RETURN _end1 > _start2 AND _start1 < _end2;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sessions_clash(_start1 int, _duration1 int, _start2 int, _duration2 int) RETURNS BOOLEAN AS $$
BEGIN
	RETURN ranges_overlap(_start1, _start1 + _duration1, _start2, _start2 + _duration2);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION instructor_sessions_clash(_start1 int, _duration1 int, _start2 int, _duration2 int) RETURNS boolean AS $$
DECLARE
	_break_time int;
BEGIN
	_break_time := 1;
	RETURN ranges_overlap(_start1, _start1 + _duration1 + _break_time, _start2, _start2 + _duration2 + _break_time);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION instructor_session_allowed(_emp_id int, _date date, _start_hour int, _duration int) RETURNS boolean AS $$
BEGIN
	RETURN QUERY
	SELECT NOT EXISTS(
		SELECT 1
		FROM Sessions S JOIN Courses C ON S.course_id = C.course_id
		WHERE instructor = _emp_id AND date = _date AND instructor_sessions_clash(_start_hour, _duration, start_time, duration)
	)
END;
$$ LANGUAGE plpgsql;


-- 1
/* This routine is used to add a new employee. The inputs to the routine include the following: name, home address, contact number, email address, salary information (i.e., monthly salary for a full-time employee or hourly rate for a part-time employee), date that the employee joined the company, the employee category (manager, administrator, or instructor), and a (possibly empty) set of course areas. If the new employee is a manager, the set of course areas refers to the areas that are managed by the manager. If the new employee is an instructor, the set of course areas refers to the instructor’s specialization areas. The set of course areas must be empty if the new employee is a administrator; and non-empty, otherwise. The employee identifier is generated by the system. */
CREATE OR REPLACE PROCEDURE add_employee(_name text, _address text, _phone text, _email text, _status employee_status, _salary int, _join_date date, _category employee_category, _course_areas text[]) AS $$
DECLARE
	_job_type text;
	_emp_id int;
BEGIN;
	IF ((_category = 'administrator' OR _category = 'manager') AND _status = 'part_time') THEN
		RAISE EXCEPTION 'Administrators or managers cannot be part-time employees.';
	END IF;
	IF (_category = 'administrator' AND cardinality(_course_areas) > 0) THEN
		RAISE EXCEPTION 'Course areas must be empty for Administrators.';
	END IF;
	IF (_category <> 'administrator' AND cardinality(_course_areas) = 0) THEN
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
		FOREACH _area IN _course_areas
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
		FOREACH _area IN _course_areas
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
	SELECT job_type INTO _job_type FROM Employees WHERE eid = _emp_id;
	IF (_job_type = 'administrator' AND EXISTS(
		SELECT 1 
		FROM Offerings 
		WHERE handler = _emp_id AND registration_deadline > _depart_date
	)) THEN
		RAISE EXCEPTION 'Administrator is handling some course offering where its registration deadline is after his departure date.';
	END IF;
	IF ((_job_type = 'full_time_instructor' OR _job_type = 'part_time_instructor') AND EXISTS(
		SELECT 1
		FROM Sessions
		WHERE instructor = _emp_id AND date > _depart_date
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
	UPDATE Employees SET depart_date = _depart_date WHERE eid = _emp_id;
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
	VALUES(_cc_num, _cvv, _cust_id, CURRENT_TIMESTAMP, _expiry_date);
END;
$$ LANGUAGE plpgsql;

-- 4
/* This routine is used when a customer requests to change his/her credit card details. The inputs to the routine include the customer identifier and his/her new credit card details (credit card number, expiry date, CVV code). */
CREATE OR REPLACE PROCEDURE update_credit_card(_cust_id int, _cc_num text, _expiry_date date, _cvv text) AS $$
BEGIN
	INSERT INTO Credit_cards
	VALUES(_cc_num, _cvv, _cust_id, CURRENT_TIMESTAMP, _expiry_date);
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
CREATE OR REPLACE FUNCTION find_instructors(_course_id int, _session_date date, _session_start_hour int) 
RETURNS TABLE(emp_id int, name text) AS $$
DECLARE
	_emp_curs CURSOR FOR (
		SELECT eid, I.name AS name, job_type
		FROM (Instructors I JOIN Specializes S ON I.eid = S.eid) JOIN Courses C ON S.name = C.area
		WHERE course_id = _course_id
	);
	_emp record;
BEGIN
	OPEN _emp_curs;
	LOOP
		FETCH _emp_curs INTO _emp;
		EXIT WHEN NOT FOUND;
		
		CONTINUE WHEN _emp.job_type = 'part_time_instructor' AND instructor_month_hours(_emp.eid, EXTRACT(year FROM _session_date), EXTRACT(month FROM _session_date)) >= 30;
		
		IF (instructor_session_allowed(_emp.eid, _session_date, _session_start_hour, get_course_duration(_course_id))) THEN
			emp_id := _emp.eid;
			name := _emp.name;
			RETURN NEXT;
		END IF;
	END LOOP;
	CLOSE _emp_curs;
END;
$$ LANGUAGE plpgsql;

--7
/* This routine is used to retrieve the availability information of instructors who could be assigned to teach a specified course. The inputs to the routine include the following: course identifier, start date, and end date. The routine returns a table of records consisting of the following information: employee identifier, name, total number of teaching hours that the instructor has been assigned for this month, day (which is within the input date range [start date, end date]), and an array of the available hours for the instructor on the specified day. The output is sorted in ascending order of employee identifier and day, and the array entries are sorted in ascending order of hour. */
CREATE OR REPLACE FUNCTION get_available_instructors(_course_id int, _start_date date, _end_date date) 
RETURNS TABLE(emp_id int, name text, total_hours int, avail_day date, avail_hours int[]) AS $$
DECLARE
	_emp_curs CURSOR FOR (
		SELECT eid, I.name AS name, job_type
		FROM (Instructors I JOIN Specializes S ON I.eid = S.eid) JOIN Courses C ON S.name = C.area
		WHERE course_id = _course_id
		ORDER BY eid
	);
	_emp record;
	_date date;
	_hour int;
	_month_hours int;
	_hours_arr int[];
BEGIN
	OPEN _emp_curs;
	LOOP
		FETCH _emp_curs INTO _emp;
		EXIT WHEN NOT FOUND;
		
		_date := _start_date;
		WHILE (_date <= _end_date) LOOP
			_month_hours := instructor_month_hours(_emp.eid, EXTRACT(year FROM _date), EXTRACT(month FROM _date));
			
			CONTINUE WHEN _emp.job_type = 'part_time_instructor' AND _month_hours >= 30;
			
			_hours_arr := ARRAY[];
			_hour := 9;
			WHILE (_hour < 18) LOOP
				CONTINUE WHEN _hour >= 12 AND _hour < 14;
				
				IF (instructor_session_allowed(_emp.eid, _date, _hour, get_course_duration(_course_id))) THEN
					array_append(_hours_arr, _hour);
				END IF;
				
				_hour := _hour + 1;
			END LOOP;
			
			IF (cardinality(_hours_arr) > 0) THEN
				emp_id := _emp.eid;
				name := _emp.name;
				total_hours := _month_hours;
				avail_day := _date;
				avail_hours := _hours_arr;
				RETURN NEXT;
			END IF;
			
			_date := _date + interval '1 day';
		END LOOP;
	END LOOP;
	CLOSE _emp_curs;
END;
$$ LANGUAGE plpgsql;

--8
/* This routine is used to find all the rooms that could be used for a course session. The inputs to the routine include the following: session date, session start hour, and session duration. The routine returns a table of room identifiers. */
CREATE OR REPLACE FUNCTION find_rooms(_session_date date, _session_start_hour int, _session_duration int) 
RETURNS TABLE(room_id int) AS $$
BEGIN;
	SELECT rid
	FROM Rooms
	WHERE NOT EXISTS(
		SELECT 1
		FROM Sessions S JOIN Courses C ON S.course_id = C.course_id
		WHERE room = rid AND date = _session_date AND sessions_clash(_session_start_hour, _session_duration, start_time, duration)
	);
END;
$$ LANGUAGE plpgsql;

--9
/* This routine is used to retrieve the availability information of rooms for a specific duration. The inputs to the routine include a start date and an end date. The routine returns a table of records consisting of the following information: room identifier, room capacity, day (which is within the input date range [start date, end date]), and an array of the hours that the room is available on the specified day. The output is sorted in ascending order of room identifier and day, and the array entries are sorted in ascending order of hour. */
CREATE OR REPLACE FUNCTION get_available_rooms(_start_date date, _end_date date) 
RETURNS TABLE(room_id int, room_capacity int, day date, avail_hours int[]) AS $$
BEGIN

END;
$$ LANGUAGE plpgsql;

-- 10
/* This routine is used to add a new offering of an existing course. The inputs to the routine include the following: course offering identifier, course identifier, course fees, launch date, registration deadline, administrator’s identifier, and information for each session (session date, session start hour, and room identifier). If the input course offering information is valid, the routine will assign instructors for the sessions. If a valid instructor assignment exists, the routine will perform the necessary updates to add the course offering; otherwise, the routine will abort the course offering addition. Note that the seating capacity of the course offering must be at least equal to the course offering’s target number of registrations. */
CREATE OR REPLACE PROCEDURE add_course_offering(_offering_id int, _course_id int, _course_fees int, _launch_date date, _reg_deadline date, _admin_id int, _sessions session_info[]) AS $$
BEGIN

END;
$$ LANGUAGE plpgsql;

--11
/* This routine is used to add a new course package for sale. The inputs to the routine include the following: package name, number of free course sessions, start and end date indicating the duration that the promotional package is available for sale, and the price of the package. The course package identifier is generated by the system. If the course package information is valid, the routine will perform the necessary updates to add the new course package. */
CREATE OR REPLACE PROCEDURE add_course_package(_name text, _num_free_sessions int, _sale_start_date date, _sale_end_date date, _price int) AS $$
BEGIN

END;
$$ LANGUAGE plpgsql;

--12
/* This routine is used to retrieve the course packages that are available for sale. The routine returns a table of records with the following information for each available course package: package name, number of free course sessions, end date for promotional package, and the price of the package. */
CREATE OR REPLACE FUNCTION get_available_course_packages() 
RETURNS TABLE(name text, num_free_sessions int, sale_end_date date, price int) AS $$
BEGIN

END;
$$ LANGUAGE plpgsql;

--13
/* This routine is used when a customer requests to purchase a course package. The inputs to the routine include the customer and course package identifiers. If the purchase transaction is valid, the routine will process the purchase with the necessary updates (e.g., payment). */
CREATE OR REPLACE PROCEDURE buy_course_package(_cust_id int, _package_id int) AS $$
BEGIN

END;
$$ LANGUAGE plpgsql;

--14
/* This routine is used when a customer requests to view his/her active/partially active course package. The input to the routine is a customer identifier. The routine returns the following information as a JSON value: package name, purchase date, price of package, number of free sessions included in the package, number of sessions that have not been redeemed, and information for each redeemed session (course name, session date, session start hour). The redeemed session information is sorted in ascending order of session date and start hour. */
CREATE OR REPLACE FUNCTION get_my_course_package(_cust_id int) 
RETURNS TABLE(package_info json) AS $$
BEGIN

END;
$$ LANGUAGE plpgsql;

--15
/* This routine is used to retrieve all the available course offerings that could be registered. The routine returns a table of records with the following information for each course offering: course title, course area, start date, end date, registration deadline, course fees, and the number of remaining seats. The output is sorted in ascending order of registration deadline and course title. */
CREATE OR REPLACE FUNCTION get_available_course_offerings() 
RETURNS TABLE(course_title text, course_area text, start_date date, end_date date, reg_deadline date, course_fees int, num_rem_seats int) AS $$
BEGIN

END;
$$ LANGUAGE plpgsql;

--16
/* This routine is used to retrieve all the available sessions for a course offering that could be registered. The input to the routine is a course offering identifier. The routine returns a table of records with the following information for each available session: session date, session start hour, instructor name, and number of remaining seats for that session. The output is sorted in ascending order of session date and start hour. */
CREATE OR REPLACE FUNCTION get_available_course_sessions(_offering_id int) 
RETURNS TABLE(session_date date, session_start_hour int, instructor_name text, num_rem_seats int) AS $$
BEGIN

END;
$$ LANGUAGE plpgsql;

--17
/* This routine is used when a customer requests to register for a session in a course offering. The inputs to the routine include the following: customer identifier, course offering identifier, session number, and payment method (credit card or redemption from active package). If the registration transaction is valid, this routine will process the registration with the necessary updates (e.g., payment/redemption). */
CREATE OR REPLACE PROCEDURE register_session(_cust_id int, _offering_id int, _session_num int, _pay_by payment_method) AS $$
BEGIN

END;
$$ LANGUAGE plpgsql;

--18
/* This routine is used when a customer requests to view his/her active course registrations (i.e, registrations for course sessions that have not ended). The input to the routine is a customer identifier. The routine returns a table of records with the following information for each active registration session: course name, course fees, session date, session start hour, session duration, and instructor name. The output is sorted in ascending order of session date and session start hour. */
CREATE OR REPLACE FUNCTION get_my_registrations(_cust_id int) 
RETURNS TABLE(course_name text, course_fees int, session_date date, session_start_hour int, session_duration int, instructor_name text) AS $$
BEGIN

END;
$$ LANGUAGE plpgsql;

--19
/* This routine is used when a customer requests to change a registered course session to another session. The inputs to the routine include the following: customer identifier, course offering identifier, and new session number. If the update request is valid and there is an available seat in the new session, the routine will process the request with the necessary updates. */
CREATE OR REPLACE PROCEDURE update_course_session(_cust_id int, _offering_id int, _new_session_num int) AS $$
BEGIN

END;
$$ LANGUAGE plpgsql;

--20
/* This routine is used when a customer requests to cancel a registered course session. The inputs to the routine include the following: customer identifier, and course offering identifier. If the cancellation request is valid, the routine will process the request with the necessary updates. */
CREATE OR REPLACE PROCEDURE cancel_registration(_cust_id int, _offering_id int) AS $$
BEGIN

END;
$$ LANGUAGE plpgsql;

--21
/* This routine is used to change the instructor for a course session. The inputs to the routine include the following: course offering identifier, session number, and identifier of the new instructor. If the course session has not yet started and the update request is valid, the routine will process the request with the necessary updates. */
CREATE OR REPLACE PROCEDURE update_instructor(_offering_id int, _session_num int, _new_instructor_id int) AS $$
BEGIN

END;
$$ LANGUAGE plpgsql;

--22
/* This routine is used to change the room for a course session. The inputs to the routine include the following: course offering identifier, session number, and identifier of the new room. If the course session has not yet started and the update request is valid, the routine will process the request with the necessary updates. Note that update request should not be performed if the number of registrations for the session exceeds the seating capacity of the new room. */
CREATE OR REPLACE PROCEDURE update_room(_offering_id int, _session_num int, _new_room_id int) AS $$
BEGIN

END;
$$ LANGUAGE plpgsql;

--23
/* This routine is used to remove a course session. The inputs to the routine include the following: course offering identifier and session number. If the course session has not yet started and the request is valid, the routine will process the request with the necessary updates. The request must not be performed if there is at least one registration for the session. Note that the resultant seating capacity of the course offering could fall below the course offering’s target number of registrations, which is allowed. */
CREATE OR REPLACE PROCEDURE remove_session(_offering_id int, _session_num int) AS $$
BEGIN

END;
$$ LANGUAGE plpgsql;

--24
/* This routine is used to add a new session to a course offering. The inputs to the routine include the following: course offering identifier, new session number, new session day, new session start hour, instructor identifier for new session, and room identifier for new session. If the course offering’s registration deadline has not passed and the the addition request is valid, the routine will process the request with the necessary updates. */
CREATE OR REPLACE PROCEDURE add_session(_offering_id int, _session_num int, _date date, _start_hour int, _instructor_id int, _room_id int) AS $$
BEGIN

END;
$$ LANGUAGE plpgsql;

--25
/* This routine is used at the end of the month to pay salaries to employees. The routine inserts the new salary payment records and returns a table of records (sorted in ascending order of employee identifier) with the following information for each employee who is paid for the month: employee identifier, name, status (either part-time or full-time), number of work days for the month, number of work hours for the month, hourly rate, monthly salary, and salary amount paid. For a part-time employees, the values for number of work days for the month and monthly salary should be null. For a full-time employees, the values for number of work hours for the month and hourly rate should be null. */
CREATE OR REPLACE FUNCTION pay_salary() 
RETURNS TABLE(emp_id int, emp_name text, emp_status employee_status, num_work_days int, num_work_hours int, hourly_rate int, monthly_salary int, amount_paid int) AS $$
BEGIN

END;
$$ LANGUAGE plpgsql;

--26
/* This routine is used to identify potential course offerings that could be of interest to inactive customers. A customer is classified as an active customer if the customer has registered for some course offering in the last six months (inclusive of the current month); otherwise, the customer is considered to be inactive customer. A course area A is of interest to a customer C if there is some course offering in area A among the three most recent course offerings registered by C. If a customer has not yet registered for any course offering, we assume that every course area is of interest to that customer. The routine returns a table of records consisting of the following information for each inactive customer: customer identifier, customer name, course area A that is of interest to the customer, course identifier of a course C in area A, course title of C, launch date of course offering of course C that still accepts registrations, course offering’s registration deadline, and fees for the course offering. The output is sorted in ascending order of customer identifier and course offering’s registration deadline. */
CREATE OR REPLACE FUNCTION promote_courses() 
RETURNS TABLE(cust_id int, cust_name text, course_area text, course_id int, course_title text, launch_date date, reg_deadline date, course_fees int) AS $$
BEGIN

END;
$$ LANGUAGE plpgsql;

--27
/* This routine is used to find the top N course packages in terms of the total number of packages sold for this year (i.e., the package’s start date is within this year). The input to the routine is a positive integer number N. The routine returns a table of records consisting of the following information for each of the top N course packages: package identifier, number of included free course sessions, price of package, start date, end date, and number of packages sold. The output is sorted in descending order of number of packages sold followed by descending order of price of package. In the event that there are multiple packages that tie for the top Nth position, all these packages should be included in the output records; thus, the output table could have more than N records. It is also possible for the output table to have fewer than N records if N is larger than the number of packages launched this year. */
CREATE OR REPLACE FUNCTION top_packages(_n int) 
RETURNS TABLE(package_id int, num_free_sessions int, price int, start_date date, end_date date, num_packages_sold int) AS $$
BEGIN

END;
$$ LANGUAGE plpgsql;

--28
/* This routine is used to find the popular courses offered this year (i.e., start date is within this year). A course is popular if the course has at least two offerings this year, and for every pair of offerings of the course this year, the offering with the later start date has a higher number of registrations than that of the offering with the earlier start date. The routine returns a table of records consisting of the following information for each popular course: course identifier, course title, course area, number of offerings this year, and number of registrations for the latest offering this year. The output is sorted in descending order of the number of registrations for the latest offering this year followed by in ascending order of course identifier. */
CREATE OR REPLACE FUNCTION popular_courses() 
RETURNS TABLE(course_id int, course_title text, course_area text, num_offerings int, num_latest_regs int) AS $$
BEGIN

END;
$$ LANGUAGE plpgsql;

--29
/* This routine is used to view a monthly summary report of the company’s sales and expenses for a specified number of months. The input to the routine is a number of months (say N) and the routine returns a table of records consisting of the following information for each of the last N months (starting from the current month): month and year, total salary paid for the month, total amount of sales of course packages for the month, total registration fees paid via credit card payment for the month, total amount of refunded registration fees (due to cancellations) for the month, and total number of course registrations via course package redemptions for the month. For example, if the number of specified months is 3 and the current month is January 2021, the output will consist of one record for each of the following three months: January 2021, December 2020, and November 2020. */
CREATE OR REPLACE FUNCTION view_summary_report(_num_months int) 
RETURNS TABLE(year int, month int, total_salary_paid int, total_package_sales int, total_reg_fees int, total_refunded_fees int, total_redemptions int) AS $$
BEGIN

END;
$$ LANGUAGE plpgsql;

--30
/* This routine is used to view a report on the sales generated by each manager. The routine returns a table of records consisting of the following information for each manager: manager name, total number of course areas that are managed by the manager, total number of course offerings that ended this year (i.e., the course offering’s end date is within this year) that are managed by the manager, total net registration fees for all the course offerings that ended this year that are managed by the manager, the course offering title (i.e., course title) that has the highest total net registration fees among all the course offerings that ended this year that are managed by the manager; if there are ties, list all these top course offering titles. The total net registration fees for a course offering is defined to be the sum of the total registration fees paid for the course offering via credit card payment (excluding any refunded fees due to cancellations) and the total redemption registration fees for the course offering. The redemption registration fees for a course offering refers to the registration fees for a course offering that is paid via a redemption from a course package; this registration fees is given by the price of the course package divided by the number of sessions included in the course package (rounded down to the nearest dollar). There must be one output record for each manager in the company and the output is to be sorted by ascending order of manager name. */
CREATE OR REPLACE FUNCTION view_manager_report() 
RETURNS TABLE(manager_name text, total_num_areas int, total_offerings int, total_reg_fees int, highest_total_fees_offering text, ) AS $$
BEGIN

END;
$$ LANGUAGE plpgsql;
