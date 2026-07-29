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
  if(index < 0 || index >= size)
    return size;

  for(int i = index; i < size - 1; i++)
    current_array[i] = current_array[i + 1];

  if(size - 1 <= 0)
    reserved_size = 0;

  return ArrayResize(current_array, size - 1, reserved_size);
}

#endif // _MICROSERVICES_UTILS_ARRAY_FUNCTIONS_MQH_
