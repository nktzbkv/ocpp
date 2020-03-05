#ifndef _ocpp_objc_class_h_
#define _ocpp_objc_class_h_

#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <objc/objc.h>
#include <objc/runtime.h>

namespace ocpp {

#if __OBJC__
  template<typename T>
  constexpr const char* ocpp_encode_type_cpp(T*) {
    return @encode(T);
  }

  #define OCPP_ENCODE_TYPE(T) @encode(T)
#else
  #define OCPP_DEFINE_CPP_ENCODE(T,R) \
    constexpr const char* ocpp_encode_type_cpp(T*) { return R; }

  OCPP_DEFINE_CPP_ENCODE(void, "v")
  OCPP_DEFINE_CPP_ENCODE(void*, "^")
  OCPP_DEFINE_CPP_ENCODE(::id, "@")

  #define OCPP_ENCODE_TYPE(T) (ocpp_encode_type_cpp((T*)nullptr))
#endif

  template<typename...>
  struct list_encoder;

  template<>
  struct list_encoder<> {
    static char* encode(char* buf) {
      return buf;
    }
  };

  template<typename T>
  struct list_encoder<T> {
    static char* encode(char* buf) {
      auto type = OCPP_ENCODE_TYPE(T);
      auto length = strlen(type);
      memcpy(buf, type, length);
      return buf += length;
    }
  };

  template<typename T, typename... P>
  struct list_encoder<T, P...> {
    static char* encode(char* buf) {
      return list_encoder<P...>::encode(list_encoder<T>::encode(buf));
    }
  };

  template<int buffer_size=256>
  class function_types_encoder {
  public:
    template<typename R, typename... P>
    function_types_encoder(R(*impl)(P...)) {
      *list_encoder<R,P...>::encode(_buffer) = 0;
    }

    operator const char* () const {
      return _buffer;
    }

  protected:
    char _buffer[buffer_size];
  };

  template<typename T>
  struct objc_class_extra_bytes {
    typedef T& reference_type;
    static constexpr size_t size = sizeof(T);
  };

  template<>
  struct objc_class_extra_bytes<void> {
    typedef void reference_type;
    static constexpr size_t size = 0;
  };

  template<
    typename ivars_type = void,
    typename cvars_type = void
  >
  class objc_class {
  public:
    typedef typename objc_class_extra_bytes<ivars_type>::reference_type ivars_reference_type;
    typedef typename objc_class_extra_bytes<cvars_type>::reference_type cvars_reference_type;

    objc_class()
      : objc_class(objc_getClass("NSObject"))
    {}

    objc_class(Class superclass)
      : objc_class(superclass, "ocpp_objc_class")
    {}

    objc_class(Class superclass, const char* name) {
      char buffer[128];
      snprintf(buffer, sizeof(buffer), "%s_%zx", name, size_t(this));
      _class = objc_allocateClassPair(superclass, buffer, objc_class_extra_bytes<cvars_type>::size);
    }

    ~objc_class() {
      objc_disposeClassPair(_class);
    }

    operator Class() const {
      return _class;
    }

    operator const char*() const {
      return class_getName(_class);
    }

    const char* get_name() const {
      return class_getName(_class);
    }

    template<typename F>
    bool add_method(SEL selector, const F& impl) {
      auto* ptr = +impl;
      return class_addMethod(_class, selector, (IMP)ptr, function_types_encoder<>(ptr));
    }

    template<typename F>
    bool add_method(SEL selector, const F& impl, const char* types) {
      auto* ptr = +impl;
      return class_addMethod(_class, selector, (IMP)ptr, types);
    }

    template<typename F>
    bool add_method(const char* selector_name, const F& impl) {
      return add_method(sel_registerName(selector_name), impl);
    }

    template<typename F>
    bool add_method(const char* selector_name, const F& impl, const char* types) {
      return add_method(sel_registerName(selector_name), impl, types);
    }

    bool add_protocol(Protocol* protocol) {
      return class_addProtocol(_class, protocol);
    }

    void register_class() {
      objc_registerClassPair(_class);
    }

    void* alloc() const {
      return class_createInstance(_class, objc_class_extra_bytes<ivars_type>::size);
    }

    static ivars_reference_type get_ivars(id self) {
      return (ivars_reference_type)object_getIndexedIvars(self);
    }

  protected:
    Class _class;
  };

  template<
    typename ivars_type = void,
    typename cvars_type = void
  >
  class objc_class_builder {
  public:
    objc_class_builder()
      : _class()
    {}

    objc_class_builder(Class superclass)
      : _class(superclass)
    {}

    objc_class_builder(Class superclass, const char* name)
      : _class(superclass, name)
    {}

    objc_class_builder& assert_add_method(bool ok, SEL selector) {
      if (!ok) {
        abort();
      }
      return *this;
    }

    template<typename F>
    objc_class_builder& add_method(SEL selector, const F& impl, const char* types) {
      return assert_add_method(_class.add_method(selector, impl, types), selector);
    }

    template<typename F>
    objc_class_builder& add_method(SEL selector, const F& impl) {
      auto* ptr = +impl;
      return assert_add_method(_class.add_method(selector, ptr, function_types_encoder<>(ptr)), selector);
    }

    template<typename F>
    objc_class_builder& add_method(const char* selector_name, const F& impl) {
      return add_method(sel_registerName(selector_name), impl);
    }

    template<typename F>
    objc_class_builder& add_method(const char* selector_name, const F& impl, const char* types) {
      return add_method(sel_registerName(selector_name), impl, types);
    }

    objc_class_builder& add_protocol(Protocol* protocol) {
      if (!class_addProtocol(_class, protocol)) {
        abort();
      }
      return *this;
    }

    objc_class<ivars_type,cvars_type> build() {
      _class.register_class();
      return _class;
    }

  protected:
    objc_class<ivars_type,cvars_type> _class;
  };

}

#endif /* ndef _ocpp_objc_class_h_ */
