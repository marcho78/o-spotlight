// Calc.js - the calculator and unit conversions.
//
//   answer("2 + 2 * 3")      → { kind: "calc", value: 8, text: "8", copy: "8", ... }
//   answer("10 km to mi")    → { kind: "convert", text: "6.21371 mi", ... }
//   answer("72 °F")          → { kind: "convert", text: "22.2222 °C", ... }
//   answer("firefox")        → null
//
// The expression is parsed by hand (never eval'd): numbers (1.5, 1e3, 1,000,
// 0xff, 0b101), + - * / ^ and **, %, "x% of y", mod, !, °, parentheses,
// implicit multiplication (2pi, 3(4+5)), constants (pi, e, tau, phi) and
// functions, with or without parentheses (sqrt 2, sin(30°)).
//
// Plain JavaScript shared by the QML and tests/*.test.cjs.

var FUNCTIONS = {
  sqrt: Math.sqrt, cbrt: Math.cbrt, abs: Math.abs, exp: Math.exp,
  sin: Math.sin, cos: Math.cos, tan: Math.tan,
  asin: Math.asin, acos: Math.acos, atan: Math.atan,
  sinh: Math.sinh, cosh: Math.cosh, tanh: Math.tanh,
  ln: Math.log, log: Math.log10, log10: Math.log10, log2: Math.log2,
  floor: Math.floor, ceil: Math.ceil, round: Math.round, trunc: Math.trunc, sign: Math.sign,
  min: Math.min, max: Math.max, pow: Math.pow, hypot: Math.hypot
}

var FUNCTION_ARITY = { min: -1, max: -1, hypot: -1, pow: 2 }

var CONSTANTS = { pi: Math.PI, e: Math.E, tau: 2 * Math.PI, phi: (1 + Math.sqrt(5)) / 2 }

// Lookups by what you typed only find the tables' own entries, never
// JavaScript's ("constructor", "toString").
function lookup(table, name) {
  return Object.prototype.hasOwnProperty.call(table, name) ? table[name] : undefined
}

// ---- tokens -------------------------------------------------------------------

function normalizeInput(text) {
  return String(text || "")
    .replace(/[×✕⋅·]/g, "*")
    .replace(/÷/g, "/")
    .replace(/[−–]/g, "-")
    .replace(/π/g, " pi ")
    .replace(/τ/g, " tau ")
    .replace(/√/g, " sqrt ")
    .replace(/²/g, "^2")
    .replace(/³/g, "^3")
    .replace(/\*\*/g, "^")
}

// Splits an expression into tokens, or returns null when something in it
// isn't part of the calculator's language.
function tokenize(text) {
  var src = normalizeInput(text)
  var tokens = []
  var i = 0
  while (i < src.length) {
    var c = src.charAt(i)
    if (/\s/.test(c)) {
      i++
      continue
    }
    var rest = src.slice(i)
    var m = rest.match(/^0x[0-9a-f]+/i) || rest.match(/^0b[01]+/i) || rest.match(/^0o[0-7]+/i)
    if (m) {
      var radix = m[0].charAt(1).toLowerCase()
      tokens.push({ t: "num", v: parseInt(m[0].slice(2), radix === "x" ? 16 : radix === "b" ? 2 : 8) })
      i += m[0].length
      continue
    }
    // 1,234,567.89 (thousands separators), then plain numbers.
    m = rest.match(/^\d{1,3}(,\d{3})+(\.\d+)?(?![\d,])/) || rest.match(/^(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?/)
    if (m) {
      tokens.push({ t: "num", v: parseFloat(m[0].replace(/,/g, "")) })
      i += m[0].length
      continue
    }
    m = rest.match(/^[a-zA-Z_][a-zA-Z_0-9]*/)
    if (m) {
      tokens.push({ t: "id", v: m[0].toLowerCase() })
      i += m[0].length
      continue
    }
    if ("+-*/^%!(),°".indexOf(c) >= 0) {
      tokens.push({ t: "op", v: c })
      i++
      continue
    }
    return null
  }
  return tokens
}

// ---- parser -------------------------------------------------------------------
//
// expr    := term (("+" | "-") term)*          a + b% adds b percent of a
// term    := unary (("*" | "/" | "mod" | "%" | "of" | implicit) unary)*
// unary   := ("+" | "-") unary | power
// power   := postfix ("^" unary)?              right-associative
// postfix := primary ("!" | "%" | "°")*
// primary := number | constant | function args | "(" expr ")"

function Parser(tokens) {
  this.tokens = tokens
  this.pos = 0
  this.operators = 0
}

Parser.prototype.peek = function(offset) {
  return this.tokens[this.pos + (offset || 0)] || null
}

Parser.prototype.isOp = function(token, value) {
  return !!token && token.t === "op" && token.v === value
}

Parser.prototype.next = function() {
  return this.tokens[this.pos++] || null
}

// A value is { v: number, pct: bool } so "+ 10%" can mean "plus ten percent".
Parser.prototype.expr = function() {
  var left = this.term()
  for (;;) {
    var token = this.peek()
    if (!(this.isOp(token, "+") || this.isOp(token, "-"))) return left
    this.next()
    this.operators++
    var right = this.term()
    var sign = token.v === "+" ? 1 : -1
    if (right.pct && !left.pct) left = { v: left.v * (1 + sign * right.v), pct: false }
    else left = { v: left.v + sign * right.v, pct: false }
  }
}

// Could this token start an operand (for implicit multiplication and for
// telling "10 % 3" apart from "10%")?
Parser.prototype.startsOperand = function(token) {
  if (!token) return false
  if (token.t === "num") return true
  if (this.isOp(token, "(")) return true
  if (token.t === "id") return token.v !== "of" && token.v !== "mod" && (lookup(CONSTANTS, token.v) !== undefined || lookup(FUNCTIONS, token.v) !== undefined)
  return false
}

Parser.prototype.term = function() {
  var left = this.unary()
  for (;;) {
    var token = this.peek()
    var op = null
    if (this.isOp(token, "*") || this.isOp(token, "/")) op = token.v
    else if (token && token.t === "id" && (token.v === "mod" || token.v === "of")) op = token.v
    else if (this.isOp(token, "%") && this.startsOperand(this.peek(1))) op = "mod"
    else if (this.startsOperand(token) && token.t !== "num") op = "implicit"
    if (!op) return left
    if (op !== "implicit") this.next()
    this.operators++
    var right = this.unary()
    if (op === "*" || op === "implicit" || op === "of") left = { v: left.v * right.v, pct: false }
    else if (op === "/") left = { v: left.v / right.v, pct: false }
    else left = { v: ((left.v % right.v) + right.v) % right.v, pct: false }
  }
}

Parser.prototype.unary = function() {
  var token = this.peek()
  if (this.isOp(token, "-") || this.isOp(token, "+")) {
    this.next()
    var value = this.unary()
    return { v: token.v === "-" ? -value.v : value.v, pct: value.pct }
  }
  return this.power()
}

Parser.prototype.power = function() {
  var base = this.postfix()
  if (this.isOp(this.peek(), "^")) {
    this.next()
    this.operators++
    var exponent = this.unary()
    return { v: Math.pow(base.v, exponent.v), pct: false }
  }
  return base
}

Parser.prototype.postfix = function() {
  var value = this.primary()
  for (;;) {
    var token = this.peek()
    if (this.isOp(token, "!")) {
      this.next()
      this.operators++
      value = { v: factorial(value.v), pct: false }
    } else if (this.isOp(token, "°")) {
      this.next()
      value = { v: value.v * Math.PI / 180, pct: false }
    } else if (this.isOp(token, "%") && !this.startsOperand(this.peek(1))) {
      this.next()
      this.operators++
      value = { v: value.v / 100, pct: true }
    } else {
      return value
    }
  }
}

Parser.prototype.primary = function() {
  var token = this.next()
  if (!token) throw new Error("incomplete")
  if (token.t === "num") return { v: token.v, pct: false }
  if (this.isOp(token, "(")) {
    var inner = this.expr()
    if (!this.isOp(this.next(), ")")) throw new Error("unbalanced")
    return { v: inner.v, pct: false }
  }
  if (token.t === "id") {
    if (lookup(CONSTANTS, token.v) !== undefined) return { v: lookup(CONSTANTS, token.v), pct: false }
    var fn = lookup(FUNCTIONS, token.v)
    if (!fn) throw new Error("unknown name " + token.v)
    this.operators++
    var args = []
    if (this.isOp(this.peek(), "(")) {
      this.next()
      if (!this.isOp(this.peek(), ")")) {
        args.push(this.expr().v)
        while (this.isOp(this.peek(), ",")) {
          this.next()
          args.push(this.expr().v)
        }
      }
      if (!this.isOp(this.next(), ")")) throw new Error("unbalanced")
    } else {
      // sqrt 16, sin 30°: the function takes what follows, up to a power.
      args.push(this.power().v)
    }
    var arity = lookup(FUNCTION_ARITY, token.v) === undefined ? 1 : lookup(FUNCTION_ARITY, token.v)
    if (arity >= 0 && args.length !== arity) throw new Error("arguments")
    if (arity < 0 && args.length === 0) throw new Error("arguments")
    return { v: fn.apply(null, args), pct: false }
  }
  throw new Error("unexpected " + token.v)
}

function factorial(n) {
  if (n < 0 || n > 170 || Math.floor(n) !== n) return NaN
  var out = 1
  for (var i = 2; i <= n; i++) out *= i
  return out
}

// The value of an expression, or null. `operators` counts what the
// expression did, so a bare number ("42") isn't mistaken for a calculation.
function evaluate(text) {
  var source = String(text || "").trim().replace(/^=\s*/, "")
  if (!source || source.length > 200) return null
  var tokens = tokenize(source)
  if (!tokens || tokens.length === 0) return null
  var parser = new Parser(tokens)
  try {
    var result = parser.expr()
    if (parser.pos !== tokens.length) return null
    if (!isFinite(result.v)) return null
    return { value: clean(result.v), operators: parser.operators, percent: result.pct }
  } catch (e) {
    return null
  }
}

// ---- numbers as text ------------------------------------------------------------

// Rounds away floating-point noise (0.1 + 0.2 → 0.3).
function clean(value) {
  if (value === 0) return 0
  return Number(value.toPrecision(12))
}

function groupThousands(digits) {
  var out = ""
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 === 0) out += ","
    out += digits.charAt(i)
  }
  return out
}

// "1,234,567.891", or "1.2345e+21" for very large and very small numbers.
// `grouped: false` leaves out the thousands separators (for copying).
function format(value, options) {
  options = options || {}
  var digits = options.digits || 12
  if (!isFinite(value)) return String(value)
  if (value === 0) return "0"
  var magnitude = Math.abs(value)
  if (magnitude >= 1e15 || magnitude < 1e-9) {
    return Number(value.toPrecision(Math.min(digits, 10))).toExponential().replace(/\.?0+e/, "e")
  }
  var fixed = Number(value.toPrecision(digits))
  var text = String(fixed)
  if (/e/.test(text)) text = fixed.toFixed(Math.min(20, digits))
  var negative = text.charAt(0) === "-"
  if (negative) text = text.slice(1)
  var parts = text.split(".")
  var whole = options.grouped === false ? parts[0] : groupThousands(parts[0])
  var fraction = parts.length > 1 ? parts[1].replace(/0+$/, "") : ""
  return (negative ? "-" : "") + whole + (fraction ? "." + fraction : "")
}

// ---- units ------------------------------------------------------------------------
//
// Each unit belongs to a dimension and converts to that dimension's base unit
// by `factor` (temperatures by functions). `names` are what you can type,
// compared without case; `symbol` is how the answer is written.

var UNITS = [
  // length (meters)
  { dim: "Length", symbol: "nm", factor: 1e-9, names: ["nm", "nanometer", "nanometers", "nanometre", "nanometres"] },
  { dim: "Length", symbol: "µm", factor: 1e-6, names: ["µm", "um", "micrometer", "micrometers", "micron", "microns"] },
  { dim: "Length", symbol: "mm", factor: 0.001, names: ["mm", "millimeter", "millimeters", "millimetre", "millimetres"] },
  { dim: "Length", symbol: "cm", factor: 0.01, names: ["cm", "centimeter", "centimeters", "centimetre", "centimetres"] },
  { dim: "Length", symbol: "m", factor: 1, names: ["m", "meter", "meters", "metre", "metres"] },
  { dim: "Length", symbol: "km", factor: 1000, names: ["km", "kilometer", "kilometers", "kilometre", "kilometres", "kms"] },
  { dim: "Length", symbol: "in", factor: 0.0254, names: ["in", "inch", "inches", "\""] },
  { dim: "Length", symbol: "ft", factor: 0.3048, names: ["ft", "foot", "feet", "'"] },
  { dim: "Length", symbol: "yd", factor: 0.9144, names: ["yd", "yds", "yard", "yards"] },
  { dim: "Length", symbol: "mi", factor: 1609.344, names: ["mi", "mile", "miles"] },
  { dim: "Length", symbol: "nmi", factor: 1852, names: ["nmi", "nautical mile", "nautical miles"] },
  // mass (kilograms)
  { dim: "Mass", symbol: "mg", factor: 1e-6, names: ["mg", "milligram", "milligrams"] },
  { dim: "Mass", symbol: "g", factor: 0.001, names: ["g", "gram", "grams", "gramme", "grammes"] },
  { dim: "Mass", symbol: "kg", factor: 1, names: ["kg", "kgs", "kilo", "kilos", "kilogram", "kilograms"] },
  { dim: "Mass", symbol: "t", factor: 1000, names: ["t", "tonne", "tonnes", "metric ton", "metric tons"] },
  { dim: "Mass", symbol: "oz", factor: 0.028349523125, names: ["oz", "ounce", "ounces"] },
  { dim: "Mass", symbol: "lb", factor: 0.45359237, names: ["lb", "lbs", "pound", "pounds"] },
  { dim: "Mass", symbol: "st", factor: 6.35029318, names: ["st", "stone", "stones"] },
  // volume (liters)
  { dim: "Volume", symbol: "ml", factor: 0.001, names: ["ml", "milliliter", "milliliters", "millilitre", "millilitres"] },
  { dim: "Volume", symbol: "cl", factor: 0.01, names: ["cl", "centiliter", "centiliters", "centilitre", "centilitres"] },
  { dim: "Volume", symbol: "dl", factor: 0.1, names: ["dl", "deciliter", "deciliters", "decilitre", "decilitres"] },
  { dim: "Volume", symbol: "L", factor: 1, names: ["l", "liter", "liters", "litre", "litres"] },
  { dim: "Volume", symbol: "m³", factor: 1000, names: ["m3", "m³", "cubic meter", "cubic meters", "cubic metre", "cubic metres"] },
  { dim: "Volume", symbol: "tsp", factor: 0.00492892159375, names: ["tsp", "teaspoon", "teaspoons"] },
  { dim: "Volume", symbol: "tbsp", factor: 0.01478676478125, names: ["tbsp", "tablespoon", "tablespoons"] },
  { dim: "Volume", symbol: "fl oz", factor: 0.0295735295625, names: ["fl oz", "floz", "fluid ounce", "fluid ounces"] },
  { dim: "Volume", symbol: "cups", factor: 0.2365882365, names: ["cup", "cups"] },
  { dim: "Volume", symbol: "pt", factor: 0.473176473, names: ["pt", "pint", "pints"] },
  { dim: "Volume", symbol: "qt", factor: 0.946352946, names: ["qt", "quart", "quarts"] },
  { dim: "Volume", symbol: "gal", factor: 3.785411784, names: ["gal", "gallon", "gallons"] },
  // time (seconds)
  { dim: "Time", symbol: "ms", factor: 0.001, names: ["ms", "millisecond", "milliseconds"] },
  { dim: "Time", symbol: "s", factor: 1, names: ["s", "sec", "secs", "second", "seconds"] },
  { dim: "Time", symbol: "min", factor: 60, names: ["min", "mins", "minute", "minutes"] },
  { dim: "Time", symbol: "h", factor: 3600, names: ["h", "hr", "hrs", "hour", "hours"] },
  { dim: "Time", symbol: "days", factor: 86400, names: ["d", "day", "days"] },
  { dim: "Time", symbol: "weeks", factor: 604800, names: ["wk", "wks", "week", "weeks"] },
  { dim: "Time", symbol: "months", factor: 2629746, names: ["month", "months"] },
  { dim: "Time", symbol: "years", factor: 31556952, names: ["y", "yr", "yrs", "year", "years"] },
  // digital storage (bytes)
  { dim: "Data", symbol: "bits", factor: 0.125, names: ["bit", "bits"] },
  { dim: "Data", symbol: "B", factor: 1, names: ["b", "byte", "bytes"] },
  { dim: "Data", symbol: "KB", factor: 1e3, names: ["kb", "kilobyte", "kilobytes"] },
  { dim: "Data", symbol: "MB", factor: 1e6, names: ["mb", "megabyte", "megabytes"] },
  { dim: "Data", symbol: "GB", factor: 1e9, names: ["gb", "gigabyte", "gigabytes"] },
  { dim: "Data", symbol: "TB", factor: 1e12, names: ["tb", "terabyte", "terabytes"] },
  { dim: "Data", symbol: "PB", factor: 1e15, names: ["pb", "petabyte", "petabytes"] },
  { dim: "Data", symbol: "KiB", factor: 1024, names: ["kib", "kibibyte", "kibibytes"] },
  { dim: "Data", symbol: "MiB", factor: 1048576, names: ["mib", "mebibyte", "mebibytes"] },
  { dim: "Data", symbol: "GiB", factor: 1073741824, names: ["gib", "gibibyte", "gibibytes"] },
  { dim: "Data", symbol: "TiB", factor: 1099511627776, names: ["tib", "tebibyte", "tebibytes"] },
  { dim: "Data", symbol: "kbit", factor: 125, names: ["kbit", "kbits", "kilobit", "kilobits"] },
  { dim: "Data", symbol: "Mbit", factor: 125000, names: ["mbit", "mbits", "megabit", "megabits"] },
  { dim: "Data", symbol: "Gbit", factor: 125000000, names: ["gbit", "gbits", "gigabit", "gigabits"] },
  // speed (meters per second)
  { dim: "Speed", symbol: "m/s", factor: 1, names: ["m/s", "mps", "meters per second", "metres per second"] },
  { dim: "Speed", symbol: "km/h", factor: 1 / 3.6, names: ["km/h", "kmh", "kph", "kmph", "kilometers per hour", "kilometres per hour"] },
  { dim: "Speed", symbol: "mph", factor: 0.44704, names: ["mph", "miles per hour"] },
  { dim: "Speed", symbol: "kn", factor: 1852 / 3600, names: ["kn", "kt", "kts", "knot", "knots"] },
  { dim: "Speed", symbol: "ft/s", factor: 0.3048, names: ["ft/s", "fps", "feet per second"] },
  // area (square meters)
  { dim: "Area", symbol: "cm²", factor: 1e-4, names: ["cm2", "cm²", "sq cm", "square centimeter", "square centimeters"] },
  { dim: "Area", symbol: "m²", factor: 1, names: ["m2", "m²", "sq m", "sqm", "square meter", "square meters", "square metre", "square metres"] },
  { dim: "Area", symbol: "km²", factor: 1e6, names: ["km2", "km²", "sq km", "square kilometer", "square kilometers", "square kilometre", "square kilometres"] },
  { dim: "Area", symbol: "in²", factor: 0.00064516, names: ["in2", "in²", "sq in", "square inch", "square inches"] },
  { dim: "Area", symbol: "ft²", factor: 0.09290304, names: ["ft2", "ft²", "sq ft", "sqft", "square foot", "square feet"] },
  { dim: "Area", symbol: "yd²", factor: 0.83612736, names: ["yd2", "yd²", "sq yd", "square yard", "square yards"] },
  { dim: "Area", symbol: "mi²", factor: 2589988.110336, names: ["mi2", "mi²", "sq mi", "square mile", "square miles"] },
  { dim: "Area", symbol: "acres", factor: 4046.8564224, names: ["ac", "acre", "acres"] },
  { dim: "Area", symbol: "ha", factor: 10000, names: ["ha", "hectare", "hectares"] },
  // energy (joules)
  { dim: "Energy", symbol: "J", factor: 1, names: ["j", "joule", "joules"] },
  { dim: "Energy", symbol: "kJ", factor: 1000, names: ["kj", "kilojoule", "kilojoules"] },
  { dim: "Energy", symbol: "cal", factor: 4.184, names: ["cal", "calorie", "calories"] },
  { dim: "Energy", symbol: "kcal", factor: 4184, names: ["kcal", "kilocalorie", "kilocalories"] },
  { dim: "Energy", symbol: "Wh", factor: 3600, names: ["wh", "watt hour", "watt hours"] },
  { dim: "Energy", symbol: "kWh", factor: 3.6e6, names: ["kwh", "kilowatt hour", "kilowatt hours"] },
  // power (watts)
  { dim: "Power", symbol: "W", factor: 1, names: ["w", "watt", "watts"] },
  { dim: "Power", symbol: "kW", factor: 1000, names: ["kw", "kilowatt", "kilowatts"] },
  { dim: "Power", symbol: "hp", factor: 745.69987158227, names: ["hp", "horsepower"] },
  // pressure (pascals)
  { dim: "Pressure", symbol: "Pa", factor: 1, names: ["pa", "pascal", "pascals"] },
  { dim: "Pressure", symbol: "kPa", factor: 1000, names: ["kpa", "kilopascal", "kilopascals"] },
  { dim: "Pressure", symbol: "bar", factor: 1e5, names: ["bar", "bars"] },
  { dim: "Pressure", symbol: "psi", factor: 6894.757293168, names: ["psi"] },
  { dim: "Pressure", symbol: "atm", factor: 101325, names: ["atm", "atmosphere", "atmospheres"] },
  // angle (radians)
  { dim: "Angle", symbol: "°", factor: Math.PI / 180, names: ["deg", "degree", "degrees", "°"] },
  { dim: "Angle", symbol: "rad", factor: 1, names: ["rad", "radian", "radians"] },
  // temperature (kelvin, by function)
  { dim: "Temperature", symbol: "°C", toBase: function(v) { return v + 273.15 }, fromBase: function(v) { return v - 273.15 },
    names: ["°c", "c", "degc", "celsius", "centigrade", "degree celsius", "degrees celsius"] },
  { dim: "Temperature", symbol: "°F", toBase: function(v) { return (v - 32) * 5 / 9 + 273.15 }, fromBase: function(v) { return (v - 273.15) * 9 / 5 + 32 },
    names: ["°f", "f", "degf", "fahrenheit", "degree fahrenheit", "degrees fahrenheit"] },
  { dim: "Temperature", symbol: "K", toBase: function(v) { return v }, fromBase: function(v) { return v },
    names: ["k", "kelvin", "kelvins"] }
]

// What a bare quantity ("10 km") converts to, by symbol.
var COUNTERPARTS = {
  "km": "mi", "mi": "km", "m": "ft", "ft": "m", "cm": "in", "in": "cm", "mm": "in", "yd": "m",
  "kg": "lb", "lb": "kg", "g": "oz", "oz": "g", "st": "kg",
  "L": "gal", "gal": "L", "ml": "fl oz", "fl oz": "ml", "cups": "ml", "pt": "ml", "qt": "L",
  "km/h": "mph", "mph": "km/h", "kn": "km/h",
  "m²": "ft²", "ft²": "m²", "km²": "mi²", "mi²": "km²", "acres": "ha", "ha": "acres",
  "°C": "°F", "°F": "°C",
  "kcal": "kJ", "kJ": "kcal", "hp": "kW", "kW": "hp", "psi": "bar", "bar": "psi"
}

// Units that mean something else on their own ("5 c" is more likely a search
// than a temperature), so a bare quantity needs the full name.
var BARE_UNSAFE = ["c", "f", "k", "t", "s", "b", "d", "h", "y", "g", "m", "l", "j", "w", "in", "st", "pt", "ac", "kn", "kt", "ms"]

var unitIndex = null

function unitByName(name) {
  if (!unitIndex) {
    unitIndex = {}
    for (var i = 0; i < UNITS.length; i++) {
      for (var j = 0; j < UNITS[i].names.length; j++) unitIndex[UNITS[i].names[j]] = UNITS[i]
    }
  }
  var key = String(name || "").trim().toLowerCase().replace(/\s+/g, " ")
  if (lookup(unitIndex, key)) return lookup(unitIndex, key)
  // "degrees C", "° F"
  key = key.replace(/^(degrees?|deg|°) ?/, "°")
  return lookup(unitIndex, key) || null
}

function unitBySymbol(symbol) {
  for (var i = 0; i < UNITS.length; i++) if (UNITS[i].symbol === symbol) return UNITS[i]
  return null
}

function toBase(unit, value) {
  return unit.toBase ? unit.toBase(value) : value * unit.factor
}

function fromBase(unit, value) {
  return unit.fromBase ? unit.fromBase(value) : value / unit.factor
}

// Converts between units of the same dimension, or returns null.
function convertValue(value, from, to) {
  if (!from || !to || from.dim !== to.dim) return null
  return clean(fromBase(to, toBase(from, value)))
}

// Splits "10.5 km" into the number and the unit's name.
function quantity(text) {
  var m = String(text || "").trim().match(/^(-?(?:\d{1,3}(?:,\d{3})+|\d*\.?\d+)(?:e[+-]?\d+)?)\s*(.+)$/i)
  if (!m) return null
  var value = parseFloat(m[1].replace(/,/g, ""))
  var unit = unitByName(m[2])
  if (!isFinite(value) || !unit) return null
  return { value: value, unit: unit, name: m[2].trim() }
}

var RADIX = { hex: 16, hexadecimal: 16, bin: 2, binary: 2, oct: 8, octal: 8, dec: 10, decimal: 10 }

function radixText(value, radix) {
  var prefix = radix === 16 ? "0x" : radix === 2 ? "0b" : radix === 8 ? "0o" : ""
  var text = Math.abs(value).toString(radix)
  if (radix === 16) text = text.toUpperCase()
  return (value < 0 ? "-" : "") + prefix + text
}

// "10 km to mi", "72°F in C", "1 gb as mib", "255 to hex", or a bare "10 km".
function conversion(query) {
  var text = String(query || "").trim()
  if (!text || text.length > 80) return null
  // Split at the last "to"/"in"/"as", so "5 in to cm" reads as inches.
  var parts = text.match(/^(.+)\s(?:to|in|into|as)\s+(.+)$/i) || text.match(/^(.+?)\s*(?:=|->|→)\s*(.+)$/)
  if (parts) {
    var target = parts[2].trim().toLowerCase()
    if (lookup(RADIX, target) !== undefined) {
      var number = evaluate(parts[1])
      if (!number || Math.floor(number.value) !== number.value || Math.abs(number.value) > 9007199254740991) return null
      var radixValue = radixText(number.value, lookup(RADIX, target))
      return { kind: "convert", value: number.value, text: radixValue, copy: radixValue, expression: parts[1].trim(), dimension: "Number" }
    }
    var from = quantity(parts[1])
    var to = unitByName(parts[2])
    if (!from || !to) return null
    var value = convertValue(from.value, from.unit, to)
    if (value === null) return null
    return converted(from.value, from.unit, value, to)
  }
  var bare = quantity(text)
  if (!bare || BARE_UNSAFE.indexOf(bare.name.toLowerCase()) >= 0) return null
  var counterpart = unitBySymbol(lookup(COUNTERPARTS, bare.unit.symbol))
  if (!counterpart) return null
  return converted(bare.value, bare.unit, convertValue(bare.value, bare.unit, counterpart), counterpart)
}

function unitText(value, unit) {
  var number = format(value, { digits: 6 })
  if (unit.symbol.charAt(0) === "°" && unit.dim === "Temperature") return number + " " + unit.symbol
  if (unit.symbol === "°") return number + "°"
  return number + " " + unit.symbol
}

function converted(fromValue, fromUnit, value, toUnit) {
  return {
    kind: "convert",
    value: value,
    text: unitText(value, toUnit),
    copy: format(value, { digits: 6, grouped: false }),
    expression: unitText(fromValue, fromUnit),
    dimension: fromUnit.dim
  }
}

// "1200*3+15%" → "1200 × 3 + 15%", for showing what was calculated.
function pretty(text) {
  return String(text || "")
    .replace(/\*\*/g, "^")
    .replace(/\s*([+*/×÷^])\s*/g, " $1 ")
    .replace(/(\S)\s*-\s*(?=[\d(.a-z√π])/gi, "$1 − ")
    .replace(/ \* /g, " × ")
    .replace(/ \/ /g, " ÷ ")
    .replace(/\s+/g, " ")
    .trim()
}

// ---- the answer Spotlight shows ---------------------------------------------------------

// A calculation or conversion for the query, or null when it isn't one.
function answer(query) {
  var text = String(query || "").trim()
  if (!text) return null
  var unitAnswer = conversion(text)
  if (unitAnswer) return unitAnswer
  var result = evaluate(text)
  // A bare number or constant ("42", "pi") isn't a calculation.
  if (!result || result.operators === 0) return null
  return {
    kind: "calc",
    value: result.value,
    text: format(result.value),
    copy: format(result.value, { grouped: false }),
    expression: pretty(text.replace(/^=\s*/, "")),
    dimension: ""
  }
}
