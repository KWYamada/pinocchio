#ifdef NO_IMPORT_ARRAY
#undef NO_IMPORT_ARRAY
#endif
#ifdef NO_IMPORT_UFUNC
#undef NO_IMPORT_UFUNC
#endif
#ifdef NO_IMPORT
#undef NO_IMPORT
#endif

#ifndef PY_ARRAY_UNIQUE_SYMBOL
#define PY_ARRAY_UNIQUE_SYMBOL EIGENPY_ARRAY_API
#endif

#ifndef PY_UFUNC_UNIQUE_SYMBOL
#define PY_UFUNC_UNIQUE_SYMBOL EIGENPY_UFUNC_API
#endif

#include <stdexcept>

extern "C" {
// Provide storage for the NumPy C-API tables when the headers were first
// included with NO_IMPORT_* flags via the precompiled header.
void **EIGENPY_ARRAY_API = nullptr;
int EIGENPY_ARRAY_APIPyArray_RUNTIME_VERSION = 0;
void **EIGENPY_UFUNC_API = nullptr;

#include <Python.h>
#include <numpy/arrayobject.h>
#include <numpy/ufuncobject.h>
}

#include <eigenpy/numpy.hpp>

namespace {

PyObject* ImportNumpyModule() {
  PyObject* numpy = PyImport_ImportModule("numpy._core._multiarray_umath");
  if (!numpy && PyErr_ExceptionMatches(PyExc_ModuleNotFoundError)) {
    PyErr_Clear();
    numpy = PyImport_ImportModule("numpy.core._multiarray_umath");
  }
  return numpy;
}

int ImportMultiarrayAPI() {
  if (EIGENPY_ARRAY_API != nullptr) {
    return 0;
  }

  PyObject* numpy = ImportNumpyModule();
  if (!numpy) {
    return -1;
  }

  PyObject* c_api = PyObject_GetAttrString(numpy, "_ARRAY_API");
  Py_DECREF(numpy);
  if (!c_api) {
    return -1;
  }

  if (!PyCapsule_CheckExact(c_api)) {
    PyErr_SetString(PyExc_RuntimeError, "_ARRAY_API is not PyCapsule object");
    Py_DECREF(c_api);
    return -1;
  }

  EIGENPY_ARRAY_API = static_cast<void**>(PyCapsule_GetPointer(c_api, nullptr));
  Py_DECREF(c_api);
  if (!EIGENPY_ARRAY_API) {
    PyErr_SetString(PyExc_RuntimeError, "_ARRAY_API is NULL pointer");
    return -1;
  }

  if (sizeof(Py_ssize_t) != sizeof(Py_intptr_t) &&
      PyArray_GetNDArrayCVersion() < NPY_2_0_API_VERSION) {
    PyErr_Format(PyExc_RuntimeError,
                 "module compiled against NumPy 2.0 but running on NumPy 1.x. "
                 "This is unsupported when sizeof(size_t) != sizeof(intptr_t).");
    return -1;
  }

  if (NPY_VERSION < PyArray_GetNDArrayCVersion()) {
    PyErr_Format(PyExc_RuntimeError,
                 "module compiled against ABI version 0x%x but this NumPy exposes 0x%x",
                 static_cast<int>(NPY_VERSION),
                 static_cast<int>(PyArray_GetNDArrayCVersion()));
    return -1;
  }

  PyArray_RUNTIME_VERSION =
      static_cast<int>(PyArray_GetNDArrayCFeatureVersion());
  if (NPY_FEATURE_VERSION > PyArray_RUNTIME_VERSION) {
    PyErr_Format(
        PyExc_RuntimeError,
        "module compiled against NumPy C-API version 0x%x but runtime is 0x%x",
        static_cast<int>(NPY_FEATURE_VERSION), PyArray_RUNTIME_VERSION);
    return -1;
  }

  const int endianness = PyArray_GetEndianness();
  if (endianness == NPY_CPU_UNKNOWN_ENDIAN) {
    PyErr_SetString(PyExc_RuntimeError,
                    "FATAL: module compiled as unknown endian");
    return -1;
  }
#if NPY_BYTE_ORDER == NPY_BIG_ENDIAN
  if (endianness != NPY_CPU_BIG) {
    PyErr_SetString(PyExc_RuntimeError,
                    "FATAL: module compiled as big endian, but detected "
                    "different endianness at runtime");
    return -1;
  }
#elif NPY_BYTE_ORDER == NPY_LITTLE_ENDIAN
  if (endianness != NPY_CPU_LITTLE) {
    PyErr_SetString(PyExc_RuntimeError,
                    "FATAL: module compiled as little endian, but detected "
                    "different endianness at runtime");
    return -1;
  }
#endif

  return 0;
}

int ImportUfuncAPI() {
  if (EIGENPY_UFUNC_API != nullptr) {
    return 0;
  }

  PyObject* numpy = ImportNumpyModule();
  if (!numpy) {
    PyErr_SetString(PyExc_ImportError,
                    "_multiarray_umath failed to import for ufunc API");
    return -1;
  }

  PyObject* c_api = PyObject_GetAttrString(numpy, "_UFUNC_API");
  Py_DECREF(numpy);
  if (!c_api) {
    PyErr_SetString(PyExc_AttributeError, "_UFUNC_API not found");
    return -1;
  }

  if (!PyCapsule_CheckExact(c_api)) {
    PyErr_SetString(PyExc_RuntimeError, "_UFUNC_API is not PyCapsule object");
    Py_DECREF(c_api);
    return -1;
  }

  EIGENPY_UFUNC_API = static_cast<void**>(PyCapsule_GetPointer(c_api, nullptr));
  Py_DECREF(c_api);
  if (!EIGENPY_UFUNC_API) {
    PyErr_SetString(PyExc_RuntimeError, "_UFUNC_API is NULL pointer");
    return -1;
  }

  return 0;
}

struct EigenPyNumpyInitializer {
  EigenPyNumpyInitializer() {
    if (ImportMultiarrayAPI() < 0) {
      PyErr_Print();
      throw std::runtime_error("Failed to initialize NumPy C-API");
    }
    if (ImportUfuncAPI() < 0) {
      PyErr_Print();
      throw std::runtime_error("Failed to initialize NumPy ufunc C-API");
    }
    eigenpy::import_numpy();
  }
};

}  // namespace

void pinocchio_numpy_init() {
  static EigenPyNumpyInitializer eigenpy_numpy_initializer;
}

