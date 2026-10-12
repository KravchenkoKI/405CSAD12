#include <gtest/gtest.h>

#include "../math_operations.h"

TEST(BasicAddition, PositiveNumbers) {
	EXPECT_EQ(add(2, 3), 5);
}

TEST(BasicAddition, NegativeNumbers) {
	EXPECT_EQ(add(-2, -3), -5);
}

TEST(BasicAddition, Zero) {
	EXPECT_EQ(add(0, 0), 0);
	EXPECT_EQ(add(7, 0), 7);
	EXPECT_EQ(add(0, -7), -7);
}
