pls remember to push and pull

-- Assumptions (can write in report)

procedure 24 (`add_session`) asks for a session start hour, but does not ask for a duration or a end time. as such we assume all sessions last exactly 1h (duration === 1).

although 2) Application says that a session only needs a day (and not a date), procedure 10 (`add_course_offering`) asks for a session date. thus we store the full date for each session, and derive the day
