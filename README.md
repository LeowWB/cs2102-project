pls remember to push and pull

-- Assumptions

according to 2) Application
session info only need day of week and hour of day

but later on,

proc 8 says session needs date and duration
proc 10 says session needs date (and no duration)

so we assume duration always === 1 and so only need to store the start hour
and we cannot just store day of week, so we store the full date.