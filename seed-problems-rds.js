#!/usr/bin/env node
/**
 * Standalone script to seed problems & testcases into the production RDS database.
 *
 * Usage:
 *   1. Update the CONFIG block below with your RDS credentials / organizer email.
 *   2. Install dependencies (once): npm install mysql2 dotenv
 *   3. Run: node seed-problems-rds.js
 */

const mysql = require("mysql2/promise");
const dotenv = require("dotenv");
const { randomUUID } = require("crypto");

dotenv.config();

//#region CONFIG – update these values before running
const CONFIG = {
  db: {
    host: process.env.DB_HOST || "quantum-judge-dev.capsi2agwav9.us-east-1.rds.amazonaws.com",
    port: parseInt(process.env.DB_PORT || "3306", 10),
    user: process.env.DB_USER || "admin",
    password: process.env.DB_PASS || "!zX*HFjR[aTd5Zkz",
    database: process.env.DB_NAME || "quantum_judge",
  },
  organizerEmail: process.env.ORGANIZER_EMAIL || "admin@gmail.com",
};
//#endregion

const ProblemAccess = {
  PUBLIC: "PUBLIC",
  PRIVATE: "PRIVATE",
};

//#region INLINE PROBLEMS

const problems = [
  {
    title: "Longest Increasing Subsequence",
    difficulty: "Hard",
    accessType: ProblemAccess.PUBLIC,
    description:
      "Given an integer array nums, return the length of the longest strictly increasing subsequence.",
    inputFormat: "First line: integer N\nSecond line: N integers.",
    outputFormat: "Print the length of the longest strictly increasing subsequence.",
    constraints: "1 ≤ N ≤ 10^5, -10^9 ≤ nums[i] ≤ 10^9",
    additionalInfo: "Use dynamic programming with binary search (O(N log N)).",
    visibleTests: [
      { input: "8\n10 9 2 5 3 7 101 18\n", expectedOutput: "4\n" },
      { input: "6\n0 1 0 3 2 3\n", expectedOutput: "4\n" },
    ],
    hiddenTests: [
      { input: "1\n10\n", expectedOutput: "1\n" },
      { input: "5\n5 4 3 2 1\n", expectedOutput: "1\n" },
      { input: "5\n1 2 3 4 5\n", expectedOutput: "5\n" },
      { input: "7\n3 4 -1 0 6 2 3\n", expectedOutput: "4\n" },
      { input: "10\n1 11 2 10 4 5 2 1 3 7\n", expectedOutput: "5\n" },
      { input: "6\n2 2 2 2 2 2\n", expectedOutput: "1\n" },
      { input: "9\n0 8 4 12 2 10 6 14 1\n", expectedOutput: "4\n" },
      { input: "7\n7 7 7 7 7 7 7\n", expectedOutput: "1\n" },
    ],
  },
  {
    title: "0/1 Knapsack Problem",
    difficulty: "Hard",
    accessType: ProblemAccess.PUBLIC,
    description:
      "You are given weights and values of N items and a capacity W. Find the maximum total value in the knapsack without exceeding capacity W.",
    inputFormat:
      "First line: N W\nSecond line: N space-separated weights\nThird line: N space-separated values",
    outputFormat: "Print the maximum total value.",
    constraints: "1 ≤ N ≤ 1000, 1 ≤ W ≤ 10^4, 1 ≤ values[i],weights[i] ≤ 1000",
    additionalInfo: "Use bottom-up DP: dp[i][w] = max value using first i items.",
    visibleTests: [
      { input: "3 4\n4 5 1\n1 2 3\n", expectedOutput: "3\n" },
      { input: "4 7\n1 3 4 5\n1 4 5 7\n", expectedOutput: "9\n" },
    ],
    hiddenTests: [
      { input: "3 50\n10 20 30\n60 100 120\n", expectedOutput: "220\n" },
      { input: "2 3\n4 5\n1 2\n", expectedOutput: "0\n" },
      { input: "5 11\n3 4 5 9 4\n1 2 5 7 3\n", expectedOutput: "10\n" },
      { input: "4 5\n1 2 3 2\n8 4 0 5\n", expectedOutput: "17\n" },
      { input: "6 15\n6 5 6 5 4 7\n5 6 4 7 8 9\n", expectedOutput: "23\n" },
      { input: "4 10\n3 4 5 9\n2 3 4 10\n", expectedOutput: "14\n" },
      { input: "5 8\n2 3 4 5 9\n3 4 5 8 10\n", expectedOutput: "13\n" },
      { input: "5 5\n1 2 3 2 2\n2 4 4 5 3\n", expectedOutput: "9\n" },
    ],
  },
  {
    title: "Edit Distance",
    difficulty: "Hard",
    accessType: ProblemAccess.PUBLIC,
    description:
      "Given two strings word1 and word2, return the minimum number of operations required to convert word1 to word2. You may perform insertions, deletions, or substitutions.",
    inputFormat: "Two lines: string word1 and string word2.",
    outputFormat: "Print minimum number of operations.",
    constraints: "1 ≤ |word1|,|word2| ≤ 1000",
    additionalInfo: "Use classic DP approach: dp[i][j] = edit distance for first i,j chars.",
    visibleTests: [
      { input: "horse\nros\n", expectedOutput: "3\n" },
      { input: "intention\nexecution\n", expectedOutput: "5\n" },
    ],
    hiddenTests: [
      { input: "abc\nabc\n", expectedOutput: "0\n" },
      { input: "a\nb\n", expectedOutput: "1\n" },
      { input: "kitten\nsitting\n", expectedOutput: "3\n" },
      { input: "flaw\nlawn\n", expectedOutput: "2\n" },
      { input: "distance\nediting\n", expectedOutput: "5\n" },
      { input: "abcd\nabef\n", expectedOutput: "2\n" },
      { input: "abcdef\nazced\n", expectedOutput: "3\n" },
      { input: "hello\nyellow\n", expectedOutput: "2\n" },
    ],
  },
  {
    title: "Longest Palindromic Subsequence",
    difficulty: "Hard",
    accessType: ProblemAccess.PUBLIC,
    description: "Given a string s, find the length of the longest palindromic subsequence.",
    inputFormat: "Single line: string s.",
    outputFormat: "Print the length of the longest palindromic subsequence.",
    constraints: "1 ≤ |s| ≤ 1000",
    additionalInfo:
      "Use DP: dp[i][j] = LPS in substring s[i..j]. If s[i]==s[j], dp[i][j]=2+dp[i+1][j-1].",
    visibleTests: [
      { input: "bbbab\n", expectedOutput: "4\n" },
      { input: "cbbd\n", expectedOutput: "2\n" },
    ],
    hiddenTests: [
      { input: "a\n", expectedOutput: "1\n" },
      { input: "abcde\n", expectedOutput: "1\n" },
      { input: "agbdba\n", expectedOutput: "5\n" },
      { input: "aaaaa\n", expectedOutput: "5\n" },
      { input: "character\n", expectedOutput: "5\n" },
      { input: "racecar\n", expectedOutput: "7\n" },
      { input: "banana\n", expectedOutput: "5\n" },
      { input: "bbcbaba\n", expectedOutput: "5\n" },
    ],
  },
  {
    title: "Matrix Chain Multiplication",
    difficulty: "Hard",
    accessType: ProblemAccess.PUBLIC,
    description:
      "Given an array of dimensions arr[] of size N, where the i-th matrix has dimensions arr[i-1] × arr[i], find the minimum number of multiplications needed to multiply the chain.",
    inputFormat: "First line: integer N\nSecond line: N integers representing matrix dimensions.",
    outputFormat: "Print minimum number of scalar multiplications needed.",
    constraints: "2 ≤ N ≤ 1000, 1 ≤ arr[i] ≤ 500",
    additionalInfo:
      "Use DP: dp[i][j] = min multiplications for matrices i..j.",
    visibleTests: [
      { input: "5\n40 20 30 10 30\n", expectedOutput: "26000\n" },
      { input: "4\n10 20 30 40\n", expectedOutput: "18000\n" },
    ],
    hiddenTests: [
      { input: "3\n10 20 30\n", expectedOutput: "6000\n" },
      { input: "5\n10 20 30 40 30\n", expectedOutput: "30000\n" },
      { input: "6\n30 35 15 5 10 20\n", expectedOutput: "15125\n" },
      { input: "6\n10 20 30 40 30 50\n", expectedOutput: "51000\n" },
      { input: "4\n5 10 3 12\n", expectedOutput: "330\n" },
      { input: "5\n5 4 6 2 7\n", expectedOutput: "158\n" },
      { input: "4\n2 3 4 5\n", expectedOutput: "64\n" },
      { input: "5\n10 20 5 15 25\n", expectedOutput: "4750\n" },
    ],
  },
];
//#endregion

async function seed() {
  console.log("🔌 Connecting to DB...", CONFIG.db.host);
  const connection = await mysql.createConnection(CONFIG.db);

  try {
    const [organizerRows] = await connection.execute(
      "SELECT id, username, email FROM users WHERE email = ? LIMIT 1",
      [CONFIG.organIZER_EMAIL || CONFIG.organizerEmail]
    );

    const organizer = organizerRows[0];
    if (!organizer) {
      throw new Error(`Organizer (email: ${CONFIG.organizerEmail}) not found. Create the user first.`);
    }
    console.log(`👤 Using organizer: ${organizer.username} (${organizer.email})`);

    for (const p of problems) {
      const [existingRows] = await connection.execute(
        "SELECT id FROM problems WHERE title = ? LIMIT 1",
        [p.title]
      );

      if (existingRows.length) {
        console.log(`ℹ️ Problem already exists, skipping: ${p.title}`);
        continue;
      }

      const problemId = randomUUID();

      await connection.execute(
        `INSERT INTO problems
          (id, title, description, difficulty, constraints, inputFormat, outputFormat, additionalInfo, accessType, createdById)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)` ,
        [
          problemId,
          p.title,
          p.description,
          p.difficulty,
          p.constraints,
          p.inputFormat,
          p.outputFormat,
          p.additionalInfo,
          p.accessType,
          organizer.id,
        ]
      );

      console.log(`✅ Inserted problem: ${p.title}`);

      const visible = p.visibleTests.map((t) => ({ ...t, isHidden: 0 }));
      const hidden = p.hiddenTests.map((t) => ({ ...t, isHidden: 1 }));

      for (const tc of [...visible, ...hidden]) {
        await connection.execute(
          `INSERT INTO testcases (id, input, expectedOutput, isHidden, problemId)
           VALUES (?, ?, ?, ?, ?)` ,
          [randomUUID(), tc.input, tc.expectedOutput, tc.isHidden, problemId]
        );
      }
    }

    console.log("🎯 All problems seeded successfully!");
  } catch (err) {
    console.error("❌ Seed error:", err.message || err);
    process.exitCode = 1;
  } finally {
    await connection.end();
  }
}

seed();
