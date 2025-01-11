// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CampusBooking {
    struct Booking {
        address user;
        uint256 amountStaked;
        bool checkedIn;
        uint256 bookingTime; // Timestamp of when the booking was made
    }

    struct Venue {
        string name;
        uint256 capacity;
        bool isActive;
    }

    struct User {
        address userAddress;
        string name;
        uint32 regNo;
    }

    mapping(uint256 => mapping(uint256 => mapping(uint256 => mapping(address => Booking))))
        public bookings; // Tracks bookings for venue, day, hour, and user
    mapping(uint256 => mapping(uint256 => mapping(uint256 => uint256)))
        public bookedCount; // Tracks booked count for each slot
    mapping(uint256 => mapping(uint256 => mapping(uint256 => mapping(address => bool))))
        public hasBooked; // Tracks if a user has already booked a specific slot
    mapping(uint256 => bool) public publicHolidays; // Tracks public holidays
    mapping(uint256 => Venue) public venues; // Stores venues with their IDs
    mapping(address => User) public users;
    uint256 public venueCount;
    address public admin;

    event VenueAdded(uint256 indexed venueId, string name, uint256 capacity);
    event VenueUpdated(
        uint256 indexed venueId,
        string name,
        uint256 capacity,
        bool isActive
    );
    event BookingCreated(
        uint256 indexed venueId,
        uint256 day,
        uint256 hour,
        address indexed user,
        uint256 amountStaked,
        uint256 bookedCount
    );
    event CheckedIn(
        uint256 indexed venueId,
        uint256 day,
        uint256 hour,
        address indexed user
    );
    event RefundIssued(
        uint256 indexed venueId,
        uint256 day,
        uint256 hour,
        address indexed user,
        uint256 amountRefunded
    );
    event SlotAvailable(
        uint256 indexed venueId,
        uint256 day,
        uint256 hour,
        bool available
    );
    event PublicHolidayAdded(uint256 date);
    event PublicHolidayRemoved(uint256 date);
    event UserRegistered(address indexed userAddress, string name);

    constructor() {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    function registerUser(string calldata name, uint32 regNo) external {
        require(bytes(name).length > 0, "Name cannot be empty");
        users[msg.sender] = User({
            userAddress: msg.sender,
            name: name,
            regNo: regNo
        });
        emit UserRegistered(msg.sender, name);
    }

    function isUserRegistered(address userAddress) public view returns (bool) {
        return bytes(users[userAddress].name).length > 0;
    }

    function addVenue(string calldata name, uint256 capacity)
        external
        onlyAdmin
    {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(capacity > 0, "Capacity must be greater than zero");
        venues[venueCount] = Venue({
            name: name,
            capacity: capacity,
            isActive: true
        });
        emit VenueAdded(venueCount, name, capacity);
        venueCount++;
    }

    function updateVenue(
        uint256 venueId,
        string calldata name,
        uint256 capacity,
        bool isActive
    ) external onlyAdmin {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(capacity > 0, "Capacity must be greater than zero");
        Venue storage venue = venues[venueId];
        venue.name = name;
        venue.capacity = capacity;
        venue.isActive = isActive;
        emit VenueUpdated(venueId, name, capacity, isActive);
    }

    function isSlotAvailable(
        uint256 venueId,
        uint256 day,
        uint256 hour
    ) public view returns (bool) {
        Venue storage venue = venues[venueId];
        require(venue.isActive, "Venue is not active");
        return bookedCount[venueId][day][hour] < venue.capacity;
    }

    function addPublicHoliday(uint256 date) external onlyAdmin {
        require(!publicHolidays[date], "Date is already a public holiday");
        require(date > block.timestamp, "Date must be in the future");
        publicHolidays[date] = true;
        emit PublicHolidayAdded(date);
    }

    function removePublicHoliday(uint256 date) external onlyAdmin {
        require(publicHolidays[date], "Date is not a public holiday");
        delete publicHolidays[date];
        emit PublicHolidayRemoved(date);
    }

    function createBooking(
        uint256 venueId,
        uint256 day,
        uint256 hour
    ) external payable {
        require(hour >= 8 && hour <= 23, "Hour must be between 8 AM and 11 PM");
        require(!isPublicHoliday(day), "Cannot book on public holidays");
        uint256 slotTime = day + hour * 1 hours;
        require(slotTime > block.timestamp, "Cannot book in the past");
        require(
            slotTime <= block.timestamp + 2 days,
            "Can only book 2 days in advance"
        );
        require(isSlotAvailable(venueId, day, hour), "Slot is already full");
        require(
            !hasBooked[venueId][day][hour][msg.sender],
            "User already booked this slot"
        );
        require(venues[venueId].isActive, "Venue is not active");
        require(msg.value > 0, "Stake must be greater than zero");

        // Create booking
        bookings[venueId][day][hour][msg.sender] = Booking({
            user: msg.sender,
            amountStaked: msg.value,
            checkedIn: false,
            bookingTime: slotTime
        });

        bookedCount[venueId][day][hour]++;
        hasBooked[venueId][day][hour][msg.sender] = true;

        emit BookingCreated(
            venueId,
            day,
            hour,
            msg.sender,
            msg.value,
            bookedCount[venueId][day][hour]
        );
        emit SlotAvailable(
            venueId,
            day,
            hour,
            bookedCount[venueId][day][hour] < venues[venueId].capacity
        );
    }

    function isPublicHoliday(uint256 timestamp) public view returns (bool) {
        return publicHolidays[timestamp];
    }

    function cancelBooking(
        uint256 venueId,
        uint256 day,
        uint256 hour
    ) external {
        Booking storage booking = bookings[venueId][day][hour][msg.sender];
        require(
            booking.user == msg.sender,
            "Only the user who booked can cancel"
        );
        require(!booking.checkedIn, "Already checked in");
        uint256 refundAmount;
        uint256 timeUntilSlot = booking.bookingTime > block.timestamp
            ? booking.bookingTime - block.timestamp
            : 0;

        if (timeUntilSlot > 30 minutes) {
            refundAmount = booking.amountStaked / 2; // 50% refund
        } else if (timeUntilSlot > 10 minutes) {
            refundAmount = (booking.amountStaked * 75) / 100; // 75% refund
        } else {
            refundAmount = 0; // No refund for last 10 minutes
        }

        if (refundAmount > 0) {
            payable(msg.sender).transfer(refundAmount);
        }

        delete bookings[venueId][day][hour][msg.sender];
        bookedCount[venueId][day][hour]--;
        hasBooked[venueId][day][hour][msg.sender] = false;

        emit RefundIssued(venueId, day, hour, msg.sender, refundAmount);
        emit SlotAvailable(
            venueId,
            day,
            hour,
            bookedCount[venueId][day][hour] < venues[venueId].capacity
        );
    }

    function getDailyBookings(uint256 venueId, uint256 day)
        external
        view
        returns (
            uint256[] memory timeSlots,
            uint256[] memory bookedSlots,
            uint256[] memory remainingSlots
        )
    {
        Venue storage venue = venues[venueId];
        require(venue.isActive, "Venue is not active");

        uint256 openHour = 8;
        uint256 closeHour = 23;
        uint256 totalHours = closeHour - openHour + 1;

        // Initialize arrays to store results
        timeSlots = new uint256[](totalHours);
        bookedSlots = new uint256[](totalHours);
        remainingSlots = new uint256[](totalHours);

        for (uint256 i = 0; i < totalHours; i++) {
            uint256 hour = openHour + i;
            timeSlots[i] = hour;
            bookedSlots[i] = bookedCount[venueId][day][hour];
            remainingSlots[i] = venue.capacity > bookedSlots[i]
                ? venue.capacity - bookedSlots[i]
                : 0; // Remaining slots
        }

        return (timeSlots, bookedSlots, remainingSlots);
    }

    function getAllVenues() external view returns (Venue[] memory) {
        Venue[] memory venuesList = new Venue[](venueCount);

        for (uint256 i = 0; i < venueCount; i++) {
            venuesList[i] = venues[i];
        }

        return venuesList;
    }

    function getAdminAddress() external view returns (address) {
        return admin;
    }

    function getUserDetails(address userAddress)
        public
        view
        returns (string memory, uint32)
    {
        require(
            bytes(users[userAddress].name).length > 0,
            "User not registered"
        );
        return (users[userAddress].name, users[userAddress].regNo);
    }
}
