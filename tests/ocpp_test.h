namespace test {
  namespace {
    class Test;
    class Runner;

    static Test* all_tests = nullptr;
    class Test {
    public:
      Test(const char* name, void(*function)())
        : next(all_tests)
        , name(name)
        , function(function)
      {
        all_tests = this;
      }

    protected:
      friend class Runner;
      Test* next;
      const char* name;
      void(*function)();
    };

    class Runner {
    public:
      void run(Test* test = all_tests) {
        if (!test) return;
        run(test->next);
        test->function();
      }
    };
  }
}

#define TEST(name) \
  static void _test_function_##name(); \
  static test::Test _test_registration_##name(#name, &_test_function_##name); \
  static void _test_function_##name()

int main() {
  test::Runner().run();
  return 0;
}
