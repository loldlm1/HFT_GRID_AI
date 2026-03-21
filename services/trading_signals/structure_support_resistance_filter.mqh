//+------------------------------------------------------------------+
//|                 structure_support_resistance_filter.mqh         |
//+------------------------------------------------------------------+
#ifndef _SVC_TS_SR_FILTER_MQH_
#define _SVC_TS_SR_FILTER_MQH_

struct SupportResistanceRetestZone
{
  int    anchor_index;
  int    reference_index;
  bool   anchor_is_peak;
  double anchor_price;
  double reference_price;
  double lower_percent;
  double upper_percent;
  double lower_price;
  double upper_price;

  SupportResistanceRetestZone()
  {
    anchor_index = -1;
    reference_index = -1;
    anchor_is_peak = false;
    anchor_price = 0.0;
    reference_price = 0.0;
    lower_percent = 0.0;
    upper_percent = 0.0;
    lower_price = 0.0;
    upper_price = 0.0;
  }
};

struct SupportResistanceRetestChainResult
{
  bool                        passed;
  int                         required_count;
  int                         matched_count;
  int                         first_match_index;
  int                         last_match_index;
  double                      evaluated_price;
  SupportResistanceRetestZone matched_zone;

  SupportResistanceRetestChainResult()
  {
    passed = false;
    required_count = 0;
    matched_count = 0;
    first_match_index = -1;
    last_match_index = -1;
    evaluated_price = 0.0;
  }
};

double ResolveOscillatorExtremumPrice(const OscillatorMarketStructure &extremum)
{
  return extremum.is_peak ? extremum.extremum_high : extremum.extremum_low;
}

double ResolveSupportResistanceZonePriceEpsilon()
{
  double epsilon = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(epsilon <= 0.0)
    epsilon = 0.0001;
  return epsilon;
}

bool ResolveSupportResistanceRetestZone(const StochasticMarketStructure &structure,
                                        const int anchor_index,
                                        const double range_percent,
                                        SupportResistanceRetestZone &zone_out)
{
  zone_out = SupportResistanceRetestZone();

  int total = ArraySize(structure.os_market_structures);
  if(anchor_index < 0 || anchor_index + 1 >= total)
    return false;

  OscillatorMarketStructure anchor = structure.os_market_structures[anchor_index];
  OscillatorMarketStructure reference = structure.os_market_structures[anchor_index + 1];

  if(anchor.is_peak == reference.is_peak)
    return false;

  double anchor_price = ResolveOscillatorExtremumPrice(anchor);
  double reference_price = ResolveOscillatorExtremumPrice(reference);
  if(anchor_price <= 0.0 || reference_price <= 0.0 || anchor_price == reference_price)
    return false;

  double half_range = ResolveSupportResistanceRetestChainRangePercent(range_percent) / 2.0;
  double lower_percent = 100.0 - half_range;
  double upper_percent = 100.0 + half_range;

  double lower_price = 0.0;
  double upper_price = 0.0;

  if(anchor.is_peak)
  {
    lower_price = GetFiboTrendPeakPrice(anchor_price,
                                        reference_price,
                                        lower_percent);
    upper_price = GetFiboTrendPeakPrice(anchor_price,
                                        reference_price,
                                        upper_percent);
  }
  else
  {
    lower_price = GetFiboTrendBottomPrice(reference_price,
                                          anchor_price,
                                          lower_percent);
    upper_price = GetFiboTrendBottomPrice(reference_price,
                                          anchor_price,
                                          upper_percent);
  }

  zone_out.anchor_index = anchor_index;
  zone_out.reference_index = anchor_index + 1;
  zone_out.anchor_is_peak = anchor.is_peak;
  zone_out.anchor_price = anchor_price;
  zone_out.reference_price = reference_price;
  zone_out.lower_percent = lower_percent;
  zone_out.upper_percent = upper_percent;
  zone_out.lower_price = MathMin(lower_price, upper_price);
  zone_out.upper_price = MathMax(lower_price, upper_price);

  return (zone_out.upper_price >= zone_out.lower_price);
}

bool PriceMatchesSupportResistanceRetestZone(const SupportResistanceRetestZone &zone,
                                             const double candidate_price)
{
  double epsilon = ResolveSupportResistanceZonePriceEpsilon();

  return (candidate_price >= (zone.lower_price - epsilon) &&
          candidate_price <= (zone.upper_price + epsilon));
}

bool FindMatchingSupportResistanceRetestZone(const StochasticMarketStructure &structure,
                                             const double candidate_price,
                                             const double range_percent,
                                             const int start_index,
                                             SupportResistanceRetestZone &zone_out)
{
  zone_out = SupportResistanceRetestZone();

  int total = ArraySize(structure.os_market_structures);
  for(int anchor_index = MathMax(start_index, 3); anchor_index + 1 < total; anchor_index++)
  {
    SupportResistanceRetestZone local_zone;
    if(!ResolveSupportResistanceRetestZone(structure,
                                           anchor_index,
                                           range_percent,
                                           local_zone))
      continue;

    if(PriceMatchesSupportResistanceRetestZone(local_zone, candidate_price))
    {
      zone_out = local_zone;
      return true;
    }
  }

  return false;
}

bool EvaluateSupportResistanceRetestChain(const StochasticMarketStructure &structure,
                                          const double candidate_price,
                                          const int required_count,
                                          const double range_percent,
                                          SupportResistanceRetestChainResult &result)
{
  result = SupportResistanceRetestChainResult();
  result.required_count = ResolveSupportResistanceRetestChainCount(required_count);
  result.evaluated_price = candidate_price;

  if(candidate_price <= 0.0)
    return false;

  SupportResistanceRetestZone matched_zone;
  if(!FindMatchingSupportResistanceRetestZone(structure,
                                              candidate_price,
                                              range_percent,
                                              3,
                                              matched_zone))
    return false;

  result.first_match_index = matched_zone.anchor_index;
  result.last_match_index = matched_zone.anchor_index;
  result.matched_zone = matched_zone;

  if(result.required_count <= 1)
  {
    result.matched_count = 1;
    result.passed = true;
    return true;
  }

  result.matched_count = 2;
  if(result.matched_count >= result.required_count)
  {
    result.passed = true;
    return true;
  }

  int search_index = matched_zone.anchor_index + 1;
  double chained_price = matched_zone.anchor_price;

  while(result.matched_count < result.required_count)
  {
    SupportResistanceRetestZone historical_zone;
    if(!FindMatchingSupportResistanceRetestZone(structure,
                                                chained_price,
                                                range_percent,
                                                search_index,
                                                historical_zone))
      return false;

    result.last_match_index = historical_zone.anchor_index;
    result.matched_zone = historical_zone;
    result.matched_count++;
    search_index = historical_zone.anchor_index + 1;
    chained_price = historical_zone.anchor_price;
  }

  result.passed = true;
  return true;
}

#endif // _SVC_TS_SR_FILTER_MQH_
