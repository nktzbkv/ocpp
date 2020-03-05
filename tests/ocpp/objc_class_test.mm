//+ -Iocpp -framework Foundation
//? -fobjc-arc
//? -fno-objc-arc

#include "ocpp_test.h"

#include "objc_class.h"
#include "objc_class.h"

using namespace ocpp;

@interface Test
- (id)new;
- (void)test;
@end

TEST(default) {
  objc_class<int> c;
  c.add_method(@selector(test), [](id,SEL){
    objc_class<int>::get_ivars()++;
  });
  c.register_class();

  [[c new] test];
}
