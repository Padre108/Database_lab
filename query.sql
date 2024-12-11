-- Create the Books table
CREATE TABLE Books (
    ISBN VARCHAR(20) PRIMARY KEY,
    Title VARCHAR(255) NOT NULL,
    Author VARCHAR(255) NOT NULL,
    Genre VARCHAR(100) NOT NULL,
    Published_Year INT CHECK (Published_Year >= 1000 AND Published_Year <= 9999) NOT NULL,
    Quantity_Available INT CHECK (Quantity_Available > 0)
);

-- Create the Users table with UUID
CREATE TABLE Users (
    ID UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    Full_Name VARCHAR(255) NOT NULL,
    Email_Address VARCHAR(255) UNIQUE NOT NULL,
    Membership_Date DATE NOT NULL
);

-- Define ENUM type for status
CREATE TYPE loan_status AS ENUM ('borrowed', 'returned', 'overdue');

-- Create the Book Loans table
CREATE TABLE Book_Loans (
    User_ID UUID NOT NULL,
    Book_ISBN VARCHAR(20) NOT NULL,
    Loan_Date DATE NOT NULL,
    Return_Date DATE,
    Status loan_status NOT NULL,
    PRIMARY KEY (User_ID, Book_ISBN, Loan_Date),
    FOREIGN KEY (User_ID) REFERENCES Users(ID) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (Book_ISBN) REFERENCES Books(ISBN) ON DELETE CASCADE ON UPDATE CASCADE,
    CHECK (Return_Date IS NULL OR Return_Date >= Loan_Date) -- Ensures return date is not earlier than loan date
);


--Insert new books
INSERT INTO Books (ISBN, Title, Author, Genre, Published_Year, Quantity_Available)
VALUES ('9781234567897', 'The Great Adventure', 'John Doe', 'Adventure', 2020, 5);

INSERT INTO Books (ISBN, Title, Author, Genre, Published_Year, Quantity_Available)
VALUES ('8783568567897', 'The Land', 'John Patrick', 'Thriller', 2004, 3);

--Insert a new user
INSERT INTO Users (ID, Full_Name, Email_Address, Membership_Date)
VALUES (gen_random_uuid(), 'Jane Milca', 'jane.milca@gmail.com', CURRENT_DATE);

--Insert a new book loan
INSERT INTO Book_Loans (User_ID, Book_ISBN, Loan_Date, Return_Date, Status)
VALUES ('f5b8dd72-a1b6-4651-8d98-1160d8674146', '9781234567897', CURRENT_DATE, CURRENT_DATE + INTERVAL '7 days', 'borrowed');

--Check the books table
SELECT B.ISBN, B.Title, B.Author, B.Genre, BL.Loan_Date, BL.Return_Date, BL.Status
FROM Book_Loans BL
JOIN Books B ON BL.Book_ISBN = B.ISBN
WHERE BL.User_ID = 'f5b8dd72-a1b6-4651-8d98-1160d8674146';

--Insert a new book loan that is overdue
INSERT INTO Book_Loans (User_ID, Book_ISBN, Loan_Date, Return_Date, Status)
VALUES (
    'f5b8dd72-a1b6-4651-8d98-1160d8674146', 
    '8783568567897', 
    CURRENT_DATE - INTERVAL '14 days',  -- Loan date is 14 days ago
    CURRENT_DATE - INTERVAL '7 days',   -- Return date was 7 days ago
    'borrowed'                         -- Status is still "borrowed"
);

--Checks if the book is overdue
SELECT BL.User_ID, U.Full_Name, B.ISBN, B.Title, BL.Loan_Date, BL.Return_Date
FROM Book_Loans BL
JOIN Books B ON BL.Book_ISBN = B.ISBN
JOIN Users U ON BL.User_ID = U.ID
WHERE BL.Status = 'borrowed' AND BL.Return_Date < CURRENT_DATE;

--Checks the performance
EXPLAIN ANALYZE 
SELECT 
    bl.User_ID, 
    u.Full_Name, 
    bl.Book_ISBN, 
    b.Title, 
    bl.Loan_Date, 
    bl.Return_Date 
FROM 
    Book_Loans bl
JOIN 
    Users u ON bl.User_ID = u.ID
JOIN 
    Books b ON bl.Book_ISBN = b.ISBN
WHERE 
    bl.Status = 'borrowed' 
    AND bl.Return_Date < CURRENT_DATE;

--Trigger function to decrease quantity of books available when a book is loaned    
CREATE OR REPLACE FUNCTION decrease_quantity_on_loan()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if the quantity is available
    IF (SELECT quantity_available FROM Books WHERE ISBN = NEW.Book_ISBN) <= 0 THEN
        RAISE EXCEPTION 'No copies of the book are available for loan.';
    END IF;

    -- Decrease the quantity
    UPDATE Books
    SET quantity_available = quantity_available - 1
    WHERE ISBN = NEW.Book_ISBN;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER after_book_loan_insert
AFTER INSERT ON Book_Loans
FOR EACH ROW
EXECUTE FUNCTION decrease_quantity_on_loan();



-- Create the trigger function for checking overdue loans
CREATE OR REPLACE FUNCTION check_overdue_loans()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if the loan is overdue (borrowed for more than 7 days)
    IF (NEW.Status = 'borrowed' AND NEW.Return_Date < CURRENT_DATE) THEN
        -- Update the status to "overdue"
        UPDATE Book_Loans
        SET Status = 'overdue'
        WHERE ID = NEW.ID;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger for book loans
CREATE TRIGGER update_overdue_status
AFTER INSERT OR UPDATE ON Book_Loans
FOR EACH ROW
EXECUTE FUNCTION check_overdue_loans();

--Check the quantity of books available
SELECT ISBN, Title, Quantity_Available
FROM Books
WHERE ISBN = '8783568567897';