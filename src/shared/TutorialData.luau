-- TutorialData.luau
-- Forth Academy lesson content for the step-by-step tutorial

local TutorialData = {}

TutorialData.Lessons = {
    {
        title = "1. The Stack",
        desc = "Forth uses a 'Stack'. Imagine a pile of plates. You put numbers on top (PUSH) and take them off the top (POP).\n\nNumbers are automatically pushed onto the stack.",
        code = "10 20 30",
        hint = "Click 'STEP' to see numbers enter the stack."
    },
    {
        title = "2. Basic Math",
        desc = "Math operators ( + - * / ) take the top two numbers, do the math, and put the result back.\n\nHere, '+' takes 5 and 3, adds them to make 8.",
        code = "5 3 +",
        hint = "Watch how 5 and 3 disappear and become 8."
    },
    {
        title = "3. Reverse Polish Notation",
        desc = "Because of the stack, the operator always comes AFTER the numbers. This is called 'Postfix' or 'Reverse Polish Notation'.\n\n(10 + 2) * 5 becomes:",
        code = "10 2 + 5 *",
        hint = "First we add 10+2, THEN we multiply the result by 5."
    },
    {
        title = "4. Duplication (DUP)",
        desc = "Sometimes you need to use a number twice. 'DUP' copies the top number.",
        code = "5 DUP *",
        hint = "This effectively squares the number (5 * 5)."
    },
    {
        title = "5. Swapping (SWAP)",
        desc = "The order matters! '-' subtracts the top number from the second one.\n\nUse 'SWAP' to switch the top two numbers.",
        code = "10 2 SWAP -",
        hint = "10 - 2 = 8. But 2 - 10 = -8. Watch the SWAP."
    },
    {
        title = "6. Dropping (DROP)",
        desc = "If you have junk on the stack you don't need, use 'DROP' to throw away the top item.",
        code = "999 1 2 + DROP",
        hint = "We calculate 1+2=3, then drop it, leaving 999."
    },
    {
        title = "7. Comparison",
        desc = "Logic checks ( > < = ) consume two numbers and leave a Flag.\n\n-1 is TRUE.\n0 is FALSE.",
        code = "5 3 >",
        hint = "Is 5 greater than 3? Watch for -1."
    },
    {
        title = "8. IF Statements",
        desc = "'IF' checks the top of the stack. If it's TRUE (-1), it runs the code. If FALSE (0), it skips to 'THEN'.",
        code = "10 5 > IF 111 THEN",
        hint = "Since 10 > 5 is True, 111 will be pushed."
    },
    {
        title = "9. Infinite Loops (BEGIN AGAIN)",
        desc = "'BEGIN' marks a loop start. 'AGAIN' jumps back to BEGIN forever.\n\nThis creates an infinite loop!",
        code = "0 BEGIN 1 + AGAIN",
        hint = "Watch it count up forever! (Click RESET to stop)"
    },
    {
        title = "10. Conditional Loops (WHILE)",
        desc = "'WHILE' checks the stack. If TRUE (-1 or non-zero), continue the loop. If FALSE (0), exit.\n\n'REPEAT' jumps back to BEGIN.",
        code = "5 BEGIN DUP WHILE 1 - REPEAT",
        hint = "Counts down: 5, 4, 3, 2, 1... Stops at 0 (FALSE)."
    },
    {
        title = "11. Counting Up",
        desc = "Let's count from 1 to 5 using a loop.\n\nWe check if we're still under 6, and if so, add 1.",
        code = "1 BEGIN DUP 5 < WHILE 1 + REPEAT",
        hint = "Starts at 1, keeps adding while < 5. Ends at 5."
    },
    {
        title = "12. Defining Words",
        desc = "You can create your own words!\n\n':' starts a definition\nNext comes the name\nThen the code\n';' ends the definition",
        code = ": SQUARE DUP * ; 5 SQUARE",
        hint = "We define SQUARE as 'DUP *', then use it on 5."
    },
    {
        title = "13. Using Your Words",
        desc = "Once defined, your word works just like built-in words.\n\nHere we define DOUBLE and use it twice!",
        code = ": DOUBLE 2 * ; 3 DOUBLE DOUBLE",
        hint = "3 doubled is 6, doubled again is 12."
    },
    {
        title = "14. Words in Loops",
        desc = "Custom words work great in loops!\n\nHere we square numbers 1 through 3.",
        code = ": SQ DUP * ; 1 SQ 2 SQ 3 SQ",
        hint = "Result: 1, 4, 9 on the stack."
    }
}

return TutorialData
