// Bounded source/native tick validation and exact text conversion. No MT5 API.
#include <algorithm>
#include <array>
#include <cstdint>
#include <cstring>
#include <fstream>
#include <iostream>
#include <map>
#include <stdexcept>
#include <string>
#include <string_view>
#include <vector>

using Text = std::string_view;
using Wide = unsigned __int128;
const std::string TICK_HEADER = "<DATE>\t<TIME>\t<BID>\t<ASK>\t<LAST>\t<VOLUME>";

class Lines {
  std::ifstream input;
  std::array<char, 1048576> buffer;
  size_t offset = 0, available = 0;
  std::string joined;
public:
  explicit Lines(const char* path) : input(path, std::ios::binary) {
    if (!input) throw std::runtime_error("cannot open input");
  }
  bool Next(Text& line) {
    joined.clear();
    for (;;) {
      if (offset == available) {
        input.read(buffer.data(), buffer.size());
        available = static_cast<size_t>(input.gcount());
        offset = 0;
        if (input.bad()) throw std::runtime_error("input read failure");
        if (!available) {
          if (joined.empty()) return false;
          line = joined;
          break;
        }
      }
      const char* begin = buffer.data() + offset;
      const char* newline = static_cast<const char*>(std::memchr(begin, '\n', available - offset));
      size_t length = newline ? static_cast<size_t>(newline - begin) : available - offset;
      if (joined.size() + length + (newline ? 1 : 0) > 65536)
        throw std::runtime_error("source line exceeds 65536 bytes");
      offset += length + (newline ? 1 : 0);
      if (newline && joined.empty()) {
        line = Text(begin, length);
        break;
      }
      joined.append(begin, length);
      if (newline) {
        line = joined;
        break;
      }
    }
    if (line.find('\0') != Text::npos) throw std::runtime_error("NUL in source line");
    if (!line.empty() && line.back() == '\r') line.remove_suffix(1);
    return true;
  }
};

std::vector<Text> Split(Text line, char separator, bool quoted) {
  std::vector<Text> result;
  result.reserve(6);
  size_t start = 0;
  for (;;) {
    size_t end = line.find(separator, start);
    Text value = line.substr(start, end == Text::npos ? end : end - start);
    if (quoted && value.size() >= 2 && value.front() == '"' && value.back() == '"')
      value = value.substr(1, value.size() - 2);
    result.push_back(value);
    if (result.size() > 6) throw std::runtime_error("field count");
    if (end == Text::npos) return result;
    start = end + 1;
  }
}

int Number(Text text) {
  int value = 0;
  for (size_t i = 0; i < text.size(); ++i) {
    if (text[i] < '0' || text[i] > '9') throw std::runtime_error("timestamp grammar");
    value = value * 10 + text[i] - '0';
  }
  return value;
}

void ValidateTimestamp(Text text, bool native) {
  if (text.size() != (native ? 23 : 24)) throw std::runtime_error("timestamp length");
  char separator = native ? '.' : '-';
  if (text[4] != separator || text[7] != separator || text[10] != ' ' ||
      text[13] != ':' || text[16] != ':' || text[19] != '.' || (!native && text[23] != 'Z'))
    throw std::runtime_error("timestamp grammar");
  int year = Number(text.substr(0, 4)), month = Number(text.substr(5, 2)), day = Number(text.substr(8, 2));
  const int days[] = {0,31,28,31,30,31,30,31,31,30,31,30,31};
  if (year < 1 || month < 1 || month > 12) throw std::runtime_error("timestamp calendar");
  int limit = days[month] + (month == 2 && year % 4 == 0 && (year % 100 != 0 || year % 400 == 0));
  if (day < 1 || day > limit || Number(text.substr(11, 2)) > 23 ||
      Number(text.substr(14, 2)) > 59 || Number(text.substr(17, 2)) > 59)
    throw std::runtime_error("timestamp calendar");
  Number(text.substr(20, 3));
}

struct Price {
  Wide value = 0;
  unsigned decimals = 0;
  Text integer, fraction;
};

Price ParsePrice(Text text, bool artifacts) {
  if (text.empty() || text.size() > 64) throw std::runtime_error("price grammar");
  size_t dot = text.find('.');
  Price result;
  result.integer = text.substr(0, dot);
  result.fraction = dot == Text::npos ? Text{} : text.substr(dot + 1);
  result.decimals = static_cast<unsigned>(result.fraction.size());
  size_t first = result.integer.find_first_not_of('0');
  size_t significant = first == Text::npos ? 0 : result.integer.size() - first;
  if (result.integer.empty() || significant > 26 || result.decimals > (artifacts ? 20 : 12) ||
      significant + result.decimals > 38 || (dot != Text::npos && result.fraction.empty()))
    throw std::runtime_error("price precision/range");
  for (size_t i = 0; i < text.size(); ++i) {
    if (i == dot) continue;
    if (text[i] < '0' || text[i] > '9') throw std::runtime_error("price grammar");
    result.value = result.value * 10 + static_cast<unsigned>(text[i] - '0');
  }
  if (!result.value) throw std::runtime_error("nonpositive quote");
  result.integer.remove_prefix(first == Text::npos ? result.integer.size() : first);
  return result;
}

bool LessPrice(const Price& left, const Price& right) {
  if (left.integer.size() != right.integer.size()) return left.integer.size() < right.integer.size();
  if (left.integer != right.integer) return left.integer < right.integer;
  size_t count = std::max(left.fraction.size(), right.fraction.size());
  for (size_t i = 0; i < count; ++i) {
    char a = i < left.fraction.size() ? left.fraction[i] : '0';
    char b = i < right.fraction.size() ? right.fraction[i] : '0';
    if (a != b) return a < b;
  }
  return false;
}

Wide Power(unsigned exponent) {
  Wide value = 1;
  for (unsigned i = 0; i < exponent; ++i) value *= 10;
  return value;
}

std::string Decimal(Wide value, unsigned decimals) {
  std::string text;
  do {
    text.push_back(static_cast<char>('0' + value % 10));
    value /= 10;
  } while (value);
  while (text.size() <= decimals) text.push_back('0');
  std::reverse(text.begin(), text.end());
  if (decimals) text.insert(text.size() - decimals, 1, '.');
  return text;
}

std::string NormalizeArtifact(const Price& price, Wide& max_delta) {
  if (price.decimals <= 12) return {};
  Wide divisor = Power(price.decimals - 5);
  Wide units = (price.value + divisor / 2) / divisor;
  Wide rounded = units * divisor;
  Wide distance = price.value > rounded ? price.value - rounded : rounded - price.value;
  Wide scaled_distance = distance * Power(20 - price.decimals);
  // Only representation noise within 1e-16 is permitted, never a general price rounding policy.
  if (scaled_distance > 10000) throw std::runtime_error("quote exceeds EURUSD artifact tolerance 1e-16");
  max_delta = std::max(max_delta, scaled_distance);
  return Decimal(units, 5);
}

int main(int argc, char** argv) {
  uint64_t source_rows = 0, rows = 0, excluded = 0, ties = 0, regressions = 0;
  try {
    if (argc < 3) throw std::runtime_error("mode and input required");
    bool native = Text(argv[1]) == "audit";
    if ((native && argc != 4) || (!native && (Text(argv[1]) != "convert" || argc != 10)))
      throw std::runtime_error("invalid arguments");
    bool artifacts = !native && Text(argv[9]) == "eurusd-5dp-artifacts";
    if (!native && ((!artifacts && Text(argv[9]) != "strict") || (artifacts && Text(argv[4]) != "EURUSD")))
      throw std::runtime_error("invalid explicit price policy");
    Lines input(argv[2]);
    Text line;
    if (!input.Next(line)) throw std::runtime_error("empty input");
    if (line.substr(0, 3) == Text("\xef\xbb\xbf", 3)) line.remove_prefix(3);
    if (native) {
      if (line != TICK_HEADER) throw std::runtime_error("native header mismatch");
    } else {
      const std::vector<Text> expected = {"Exness", "Symbol", "Timestamp", "Bid", "Ask"};
      if (Split(line, ',', true) != expected) throw std::runtime_error("source header mismatch");
    }
    std::ofstream output;
    std::string pending;
    if (!native) {
      output.open(argv[3], std::ios::binary | std::ios::trunc);
      if (!output) throw std::runtime_error("cannot open output");
      pending.reserve(8 * 1024 * 1024 + 1024);
      pending = TICK_HEADER + "\n";
    }
    std::string first, last, previous;
    std::map<std::string, uint64_t> daily;
    unsigned max_bid_decimals = 0, max_ask_decimals = 0;
    uint64_t adjusted_rows = 0, adjusted_quotes = 0;
    Wide max_delta = 0;
    std::vector<std::string> examples;
    while (input.Next(line)) {
      std::vector<Text> fields = Split(line, native ? '\t' : ',', !native);
      if (fields.size() != (native ? 6 : 5)) throw std::runtime_error("field count");
      std::string native_stamp;
      Text stamp, bid, ask;
      if (native) {
        native_stamp = std::string(fields[0]) + " " + std::string(fields[1]);
        stamp = native_stamp; bid = fields[2]; ask = fields[3];
        if (fields[4] != "0" || fields[5] != "0") throw std::runtime_error("Last/Volume not zero");
      } else {
        if (fields[0] != "exness" || fields[1] != argv[4]) throw std::runtime_error("vendor/symbol mismatch");
        stamp = fields[2]; bid = fields[3]; ask = fields[4];
        if (stamp.substr(0, 10) < argv[5] || stamp.substr(0, 10) >= argv[6])
          throw std::runtime_error("archive interval");
      }
      ValidateTimestamp(stamp, native);
      Price source_bid = ParsePrice(bid, artifacts), source_ask = ParsePrice(ask, artifacts);
      if (LessPrice(source_ask, source_bid)) throw std::runtime_error("crossed source quote");
      ++source_rows;
      Wide row_delta = 0;
      std::string fixed_bid = artifacts ? NormalizeArtifact(source_bid, row_delta) : "";
      std::string fixed_ask = artifacts ? NormalizeArtifact(source_ask, row_delta) : "";
      if (!native && (stamp.substr(0, 10) < argv[7] || stamp.substr(0, 10) >= argv[8])) {
        ++excluded;
        continue;
      }
      if (!fixed_bid.empty() || !fixed_ask.empty()) {
        max_delta = std::max(max_delta, row_delta);
        ++adjusted_rows;
        adjusted_quotes += !fixed_bid.empty() + static_cast<unsigned>(!fixed_ask.empty());
        if (examples.size() < 8) examples.push_back("{\"source_row\":" + std::to_string(source_rows) +
          ",\"utc\":\"" + std::string(stamp) + "\",\"bid_before\":\"" + std::string(bid) +
          "\",\"ask_before\":\"" + std::string(ask) + "\",\"bid_after\":\"" +
          (fixed_bid.empty() ? std::string(bid) : fixed_bid) + "\",\"ask_after\":\"" +
          (fixed_ask.empty() ? std::string(ask) : fixed_ask) + "\"}");
      }
      if (!fixed_bid.empty()) bid = fixed_bid;
      if (!fixed_ask.empty()) ask = fixed_ask;
      Price target_bid = ParsePrice(bid, false), target_ask = ParsePrice(ask, false);
      if (LessPrice(target_ask, target_bid)) throw std::runtime_error("crossed prepared quote");
      max_bid_decimals = std::max(max_bid_decimals, target_bid.decimals);
      max_ask_decimals = std::max(max_ask_decimals, target_ask.decimals);
      if (rows) { regressions += stamp < previous; ties += stamp == previous; }
      if (!rows || stamp < first) first = stamp;
      if (!rows || stamp > last) last = stamp;
      previous = stamp;
      ++rows;
      ++daily[std::string(stamp.substr(0, 10))];
      if (!native) {
        std::string day(stamp.substr(0, 10)); day[4] = '.'; day[7] = '.';
        pending += day; pending += '\t'; pending.append(stamp.substr(11, 12)); pending += '\t';
        pending.append(bid); pending += '\t'; pending.append(ask); pending += "\t0\t0\n";
        if (pending.size() >= 8 * 1024 * 1024) {
          output.write(pending.data(), pending.size()); pending.clear();
          if (!output) throw std::runtime_error("output write failure");
        }
      }
    }
    if (!native) {
      output.write(pending.data(), pending.size()); output.close();
      if (!output) throw std::runtime_error("output flush failure");
    }
    if (native && rows != std::stoull(argv[3])) throw std::runtime_error("native row conservation");
    std::cout << "{\"source_rows\":" << source_rows << ",\"rows\":" << rows << ",\"outside_selection_rows\":" << excluded
      << ",\"invalid_rows\":0,\"first_utc\":\"" << first << "\",\"last_utc\":\"" << last
      << "\",\"timestamp_regressions\":" << regressions << ",\"adjacent_equal_time_rows\":" << ties
      << ",\"max_bid_decimal_places\":" << max_bid_decimals << ",\"max_ask_decimal_places\":" << max_ask_decimals
      << ",\"adjusted_rows\":" << adjusted_rows << ",\"adjusted_quotes\":" << adjusted_quotes
      << ",\"max_price_adjustment\":\"" << Decimal(max_delta, 20) << "\",\"adjustment_examples\":[";
    for (size_t i = 0; i < examples.size(); ++i) std::cout << (i ? "," : "") << examples[i];
    std::cout << "],\"daily_rows\":{";
    bool comma = false;
    for (std::map<std::string, uint64_t>::const_iterator entry = daily.begin(); entry != daily.end(); ++entry) {
      std::cout << (comma ? "," : "") << '"' << entry->first << "\":" << entry->second;
      comma = true;
    }
    std::cout << "}}\n";
    return regressions ? 4 : 0;
  } catch (const std::exception& error) {
    std::cerr << "source row " << source_rows + 1 << ": " << error.what() << '\n';
    return 3;
  }
}
