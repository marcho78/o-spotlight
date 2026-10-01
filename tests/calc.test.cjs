// Checks the calculator and unit conversions.
// Usage (from the plugin directory): node tests/calc.test.cjs

const assert = require("node:assert/strict");
const { load } = require("./load.cjs");

const Calc = load("Calc.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

const value = (text) => { const r = Calc.evaluate(text); return r ? r.value : null; };
const near = (a, b, eps = 1e-9) => assert.ok(a !== null && Math.abs(a - b) <= eps * Math.max(1, Math.abs(b)), `${a} ≉ ${b}`);

check("arithmetic and precedence", () => {
  assert.equal(value("2+2*3"), 8);
  assert.equal(value("(2+2)*3"), 12);
  assert.equal(value("2^3^2"), 512);
  assert.equal(value("-2^2"), -4);
  assert.equal(value("2**10"), 1024);
  assert.equal(value("10/4"), 2.5);
  assert.equal(value("0.1+0.2"), 0.3);
  assert.equal(value("= 7 * 6"), 42);
  assert.equal(value("7 × 6 ÷ 2 − 1"), 20);
  assert.equal(value("1,000,000 / 4"), 250000);
  assert.equal(value("0xff + 0b11"), 258);
});

check("implicit multiplication, functions, constants", () => {
  near(value("2pi"), 2 * Math.PI);
  assert.equal(value("3(4+5)"), 27);
  assert.equal(value("(1+2)(3+4)"), 21);
  assert.equal(value("sqrt 16 + 9"), 13);
  assert.equal(value("sqrt(16)"), 4);
  assert.equal(value("√16"), 4);
  near(value("sin(30°)"), 0.5);
  near(value("cos 60°"), 0.5);
  assert.equal(value("max(1, 5, 3)"), 5);
  assert.equal(value("pow(2, 8)"), 256);
  assert.equal(value("log 1000"), 3);
  near(value("ln e"), 1);
  assert.equal(value("5!"), 120);
  assert.equal(value("3²"), 9);
});

check("percent and modulo", () => {
  assert.equal(value("100 + 10%"), 110);
  assert.equal(value("200 - 25%"), 150);
  assert.equal(value("15% of 80"), 12);
  assert.equal(value("80 * 15%"), 12);
  assert.equal(value("10 % 3"), 1);
  assert.equal(value("10 mod 4"), 2);
  assert.equal(value("-7 mod 3"), 2);
});

check("not calculations", () => {
  for (const text of ["", "firefox", "42", "pi", "e", "sin", "log", "c++", "2 3", "10/0", "(1+2", "1+", "hello world", "5!!!!!!!!!!!!!!", "sqrt(-1)"]) {
    assert.equal(Calc.answer(text), null, JSON.stringify(text));
  }
  assert.equal(Calc.evaluate("x".repeat(300)), null);
});

check("JavaScript's own names are just words", () => {
  for (const text of ["constructor(2)", "toString", "10 to constructor", "5 constructor", "5 __proto__ to km",
                      "2 hasOwnProperty", "valueOf(3)", "1 km to toString", "__proto__"]) {
    assert.doesNotThrow(() => Calc.answer(text), text);
    assert.equal(Calc.answer(text), null, text);
  }
});

check("formatting", () => {
  assert.equal(Calc.format(8), "8");
  assert.equal(Calc.format(1234567.891), "1,234,567.891");
  assert.equal(Calc.format(1234567.891, { grouped: false }), "1234567.891");
  assert.equal(Calc.format(-0.5), "-0.5");
  assert.equal(Calc.format(1 / 3), "0.333333333333");
  assert.equal(Calc.format(1e-7), "0.0000001");
  assert.equal(Calc.format(2e21), "2e+21");
  assert.equal(Calc.format(0), "0");
});

check("answers", () => {
  const a = Calc.answer("1200 * 3");
  assert.equal(a.kind, "calc");
  assert.equal(a.text, "3,600");
  assert.equal(a.copy, "3600");
  assert.equal(a.expression, "1200 × 3");
  assert.equal(Calc.answer("=2+2").expression, "2 + 2");
  assert.equal(Calc.pretty("1200*3+15%"), "1200 × 3 + 15%");
  assert.equal(Calc.pretty("-2^2"), "-2 ^ 2");
  assert.equal(Calc.pretty("10-4/2"), "10 − 4 ÷ 2");
  assert.equal(Calc.pretty("sqrt(16)*2"), "sqrt(16) × 2");
});

check("conversions", () => {
  const km = Calc.answer("10 km to mi");
  assert.equal(km.kind, "convert");
  assert.equal(km.text, "6.21371 mi");
  assert.equal(km.expression, "10 km");
  assert.equal(km.dimension, "Length");
  assert.equal(Calc.answer("5 in to cm").text, "12.7 cm");
  assert.equal(Calc.answer("5 in in cm").text, "12.7 cm");
  assert.equal(Calc.answer("72 f in c").text, "22.2222 °C");
  assert.equal(Calc.answer("-40 c to f").text, "-40 °F");
  assert.equal(Calc.answer("100 degrees celsius to fahrenheit").text, "212 °F");
  assert.equal(Calc.answer("0 k to c").text, "-273.15 °C");
  assert.equal(Calc.answer("1 gb to mb").text, "1,000 MB");
  assert.equal(Calc.answer("1 gib in mb").text, "1,073.74 MB");
  assert.equal(Calc.answer("90 minutes in hours").text, "1.5 h");
  assert.equal(Calc.answer("60 mph to km/h").text, "96.5606 km/h");
  assert.equal(Calc.answer("1 fl oz to ml").text, "29.5735 ml");
  assert.equal(Calc.answer("2 cups → ml").text, "473.176 ml");
  assert.equal(Calc.answer("1,500 m = km").text, "1.5 km");
  assert.equal(Calc.answer("180 deg to rad").text, "3.14159 rad");
  assert.equal(Calc.answer("255 to hex").text, "0xFF");
  assert.equal(Calc.answer("0xff to dec").text, "255");
  assert.equal(Calc.answer("10 to binary").text, "0b1010");
  assert.equal(Calc.answer("10 km to kg"), null, "different dimensions");
  assert.equal(Calc.answer("100 usd to eur"), null, "no currencies");
});

check("bare quantities", () => {
  assert.equal(Calc.answer("10 km").text, "6.21371 mi");
  assert.equal(Calc.answer("5 miles").text, "8.04672 km");
  assert.equal(Calc.answer("72°F").text, "22.2222 °C");
  assert.equal(Calc.answer("20 celsius").text, "68 °F");
  assert.equal(Calc.answer("70 kg").text, "154.324 lb");
  // Too ambiguous on their own.
  for (const text of ["5 c", "3 m", "2 in", "10 s", "4 t"]) assert.equal(Calc.answer(text), null, text);
});

console.log(`calc: ${passed} checks passed`);
