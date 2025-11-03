//+------------------------------------------------------------------+
//|                        microservices/utils/array_functions.mqh |
//+------------------------------------------------------------------+
#ifndef _MICROSERVICES_UTILS_ARRAY_FUNCTIONS_MQH_
#define _MICROSERVICES_UTILS_ARRAY_FUNCTIONS_MQH_

template<typename ARR1>
int AddElementToArray(ARR1 &current_array[], ARR1 &new_element, int reserved_size = 100)
{
  int total     = ArraySize(current_array);
  int new_total = ArrayResize(current_array, total+1, reserved_size);

  current_array[total] = new_element;

  return new_total;
}

template<typename ARR2>
int RemoveElementFromArray(ARR2 &current_array[], int index, int reserved_size = 100) {
  int size = ArraySize(current_array);
  if(index < 0 || index >= size) return size; // Evita accesos fuera del rango

  for(int i = index; i < size - 1; i++) {
    current_array[i] = current_array[i + 1]; // Mueve los elementos hacia la izquierda
  }

  if(size - 1 <= 0) reserved_size = 0;

  return ArrayResize(current_array, size - 1, reserved_size); // Reduce el tamaño del array
}

template<typename ARR3>
void ClearArray(ARR3 &current_array[])
{
  ArrayResize(current_array, 0, 0);
}

double BasicExponentialMA(const int index, const int period, const double prev_value, const double &price[])
{
  if(period <= 0)
    return 0.0;

  double k = 2.0 / (period + 1.0);
  return price[index] * k + prev_value * (1.0 - k);
}

//+------------------------------------------------------------------+
//| Ordena el array por finish_level ascendente                      |
//+------------------------------------------------------------------+
template<typename ARR4>
int SortByFinishLevelASC(ARR4 &data[])
{
  int total = ArraySize(data);
  if(total <= 1)
    return total;

  for(int i = 0; i < total - 1; i++)
  {
    for(int j = 0; j < total - i - 1; j++)
    {
      if(data[j].finish_level > data[j + 1].finish_level)
      {
        // Swap manual
        ARR4 temp = data[j];
        data[j] = data[j + 1];
        data[j + 1] = temp;
      }
    }
  }

  return total;
}

//+------------------------------------------------------------------+
//| Ordena el array por expectations descendente                    |
//+------------------------------------------------------------------+
template<typename ARR5>
int SortByExpectationsDESC(ARR5 &data[])
{
  int total = ArraySize(data);
  if(total <= 1)
    return total;

  for(int i = 0; i < total - 1; i++)
  {
    for(int j = 0; j < total - i - 1; j++)
    {
      if(data[j].expectations < data[j + 1].expectations) // < para ordenar de MAYOR a MENOR
      {
        // Swap manual
        ARR5 temp = data[j];
        data[j] = data[j + 1];
        data[j + 1] = temp;
      }
    }
  }

  return total;
}

//+------------------------------------------------------------------+
//| Ordena el array por z_score descendente                    |
//+------------------------------------------------------------------+
template<typename ARR6>
int SortByZScoreDESC(ARR6 &data[])
{
  int total = ArraySize(data);
  if(total <= 1)
    return total;

  for(int i = 0; i < total - 1; i++)
  {
    for(int j = 0; j < total - i - 1; j++)
    {
      if(data[j].z_score < data[j + 1].z_score) // < para ordenar de MAYOR a MENOR
      {
        // Swap manual
        ARR6 temp = data[j];
        data[j] = data[j + 1];
        data[j + 1] = temp;
      }
    }
  }

  return total;
}

//+------------------------------------------------------------------+
//| Ordena el array por z_score descendente                    |
//+------------------------------------------------------------------+
template<typename ARR7>
int SortByZWinrateDESC(ARR7 &data[])
{
  int total = ArraySize(data);
  if(total <= 1)
    return total;

  for(int i = 0; i < total - 1; i++)
  {
    for(int j = 0; j < total - i - 1; j++)
    {
      if(data[j].winrate < data[j + 1].winrate) // < para ordenar de MAYOR a MENOR
      {
        // Swap manual
        ARR7 temp = data[j];
        data[j] = data[j + 1];
        data[j + 1] = temp;
      }
    }
  }

  return total;
}

//+------------------------------------------------------------------+
//| Ordena el array por z_score descendente                    |
//+------------------------------------------------------------------+
template<typename ARR8>
void QuickSortByVariantSharpeDesc(ARR8 &arr[], int left, int right)
{
  int i = left, j = right;
  double pivot = arr[(left + right) / 2].variant_sharpe_ratio;

  while(i <= j)
  {
    while(arr[i].variant_sharpe_ratio > pivot) i++;
    while(arr[j].variant_sharpe_ratio < pivot) j--;

    if(i <= j)
    {
      ARR8 tmp = arr[i];
      arr[i] = arr[j];
      arr[j] = tmp;
      i++;
      j--;
    }
  }

  if(left < j) QuickSortByVariantSharpeDesc(arr, left, j);
  if(i < right) QuickSortByVariantSharpeDesc(arr, i, right);
}
//+------------------------------------------------------------------+
//| Ordena el array por sharpe_ratio descendente                    |
//+------------------------------------------------------------------+
template<typename ARR9>
void QuickSortBySharpeDesc(ARR9 &arr[], int left, int right)
{
  int i = left, j = right;
  double pivot = arr[(left + right) / 2].sharpe_ratio;

  while(i <= j)
  {
    while(arr[i].sharpe_ratio > pivot) i++;
    while(arr[j].sharpe_ratio < pivot) j--;

    if(i <= j)
    {
      ARR9 tmp = arr[i];
      arr[i] = arr[j];
      arr[j] = tmp;
      i++;
      j--;
    }
  }

  if(left < j) QuickSortBySharpeDesc(arr, left, j);
  if(i < right) QuickSortBySharpeDesc(arr, i, right);
}

//+------------------------------------------------------------------+
//| Ordena el array por bayesian_sharpe_ratio descendente                    |
//+------------------------------------------------------------------+
template<typename ARR10>
void QuickSortByBayesianSharpeDesc(ARR10 &arr[], int left, int right)
{
  int i = left, j = right;
  double pivot = arr[(left + right) / 2].bayesian_sharpe_ratio;

  while(i <= j)
  {
    while(arr[i].bayesian_sharpe_ratio > pivot) i++;
    while(arr[j].bayesian_sharpe_ratio < pivot) j--;

    if(i <= j)
    {
      ARR10 tmp = arr[i];
      arr[i] = arr[j];
      arr[j] = tmp;
      i++;
      j--;
    }
  }

  if(left < j) QuickSortByBayesianSharpeDesc(arr, left, j);
  if(i < right) QuickSortByBayesianSharpeDesc(arr, i, right);
}

//+------------------------------------------------------------------+
//| Ordena el array por entry_time ascendente                        |
//+------------------------------------------------------------------+
template<typename ARR11>
void QuickSortByEntryTimeAsc(ARR11 &arr[], int left, int right)
{
  int i = left, j = right;
  long pivot = arr[(left + right) / 2].entry_time;

  while(i <= j)
  {
    while(arr[i].entry_time < pivot) i++;   // Ascendente
    while(arr[j].entry_time > pivot) j--;   // Ascendente

    if(i <= j)
    {
      ARR11 tmp = arr[i];
      arr[i] = arr[j];
      arr[j] = tmp;
      i++;
      j--;
    }
  }

  if(left < j) QuickSortByEntryTimeAsc(arr, left, j);
  if(i < right) QuickSortByEntryTimeAsc(arr, i, right);
}

#endif // _MICROSERVICES_UTILS_ARRAY_FUNCTIONS_MQH_
