import struct

# TODO: add finalizers to automatic variables

# 1 take pointer
# 2 deser from pointer
# 3 modify all pointer's bytearrays when original is
# 4 modify original bytearray and pointers if a pointer is
# 5 switch pointed-to value if pointer is offset onto this new value from array of CVALs

# 1 create CLIST with val = CVAL.bytestart
# 2 create CVAL with val = copied N bytes at CLIST.val
# 3 automatic when smth is changing the orig value
# 4 modify N bytes at CLIST.val 
# 5 automatic when smth is added to ptr

# CPTR has elemsize

# CPTR points somewhere
# assigning to it, means changing its .val as for the CVAL
# dereferencing it, means creating CVAL with (bytestart, size) == (CPTR.val, CPTR.elem_size)
# adding to it, means shifting its .val by some value * CPTR.elem_size
# its size == sizeof(c pointer) == sizeof(struct.calcsize('P'))

# CSIZEDARRAY points somewhere
# cannot assign it
# dereferencing it, means creating CVAL with (bytestart, size) == (CPTR.val, CPTR.elem_size)
# adding to it, means shifting its .val by some value * CPTR.elem_size
# its size == sizeof(CPTR.elem_size) * its count

# struct is a bunch of fields, that we can address directly
# each field is a non-auto CVAL__ of its own
# a.b (Python) = a.b (C)
# foo(a.b) = foo(trnslt_arg(a.b))
# foo(&a.b) = foo(trnslt_arg(trnslt_ptr(a.b)))

class gbytearray__:
    arr = bytearray()
    taken = []

    @classmethod
    def malloc(cls, bytesize):
        if len(cls.taken) == 0:
            return cls.insert_and_get(0, bytesize, 0)

        first = cls.taken[0]
        if first[0] >= bytesize:
            return cls.insert_and_get(0, bytesize, 0)

        for takenIndex in range(0, len(cls.taken) - 1):
            first = cls.taken[takenIndex]
            second = cls.taken[takenIndex + 1]
            if second[0] - first[1] >= bytesize:
                return cls.insert_and_get(first[1], first[1] + bytesize)
            else:
                continue

        back = cls.taken[-1]
        return cls.insert_and_get(back[1], back[1] + bytesize, len(cls.taken))

    @classmethod
    def free(cls, byteat):
        for i in range(len(cls.taken)):
            curbyteat = cls.taken[i][0]
            if curbyteat == byteat:
                cls.taken.pop(i)
                return
        raise ValueError("trying to free a non-existing block")

    @classmethod
    def insert_and_get(cls, l, r, at):
        if len(cls.arr) < r:
            cls.arr += bytearray(r - len(cls.arr))
        cls.taken.insert(at, (l, r))
        return cls.taken[at][0]

    @classmethod
    def get_size_of(cls, typename):
        spec = cls.get_struct_spec(typename)
        if spec is None:
            return None
        else:
            return struct.calcsize(spec)

    @classmethod
    def set_at(cls, at, subarr):
        # TODO: maybe create some method to avoid 
        # allocating tmp subarr?
        if not isinstance(at, int):
            raise ValueError("at is not int")
        if not isinstance(subarr, bytearray) and not isinstance(subarr, bytes):
            raise ValueError("subarr is not bytearray or bytes")
        cls.arr[at:at+len(subarr)] = subarr

    @classmethod
    def memcpy(cls, dst, src, size):
        if not isinstance(dst, int):
            raise ValueError("dst is not int")
        if not isinstance(src, int):
            raise ValueError("src is not int")
        if not isinstance(size, int):
            raise ValueError("size is not int")
        cls.set_at(dst, cls.arr[src:src+size])

    @classmethod
    def find_null_from(cls, start):
        return cls.arr.index(0, start)

    @classmethod
    def get_struct_spec(cls, typename):
        spec = None
        if typename == 'pad byte':
            spec = 'x'
        elif typename == 'char':
            spec = 'c'
        elif typename == 'signed char':
            spec = 'b'
        elif typename == 'unsigned char':
            spec = 'B'
        elif typename == '_Bool':
            spec = '?'
        elif typename == 'short':
            spec = 'h'
        elif typename == 'unsigned short':
            spec = 'H'
        elif typename == 'int':
            spec = 'i'
        elif typename == 'unsigned int':
            spec = 'I'
        elif typename == 'long':
            spec = 'l'
        elif typename == 'unsigned long':
            spec = 'L'
        elif typename == 'long long':
            spec = 'q'
        elif typename == 'unsigned long long':
            spec = 'Q'
        elif typename == 'ssize_t':
            spec = 'n'
        elif typename == 'size_t':
            spec = 'N'
        elif typename == 'float':
            spec = 'f'
        elif typename == 'double':
            spec = 'd'
        elif typename == 'float complex':
            spec = 'F'
        elif typename == 'double complex':
            spec = 'D'
        elif typename == 'char[]':
            raise ValueError("No arrays allowed")
        elif typename == 'void*':
            spec = 'P'
        
        return spec

def malloc__(bytesize):
    # if not isinstance(bytesize, CVAL__):
        # raise ValueError("trying to malloc with non CVAL bytesize")
    return gbytearray__.malloc(int(bytesize))

def free__(byteat):
    # if not isinstance(byteat, CVAL__):
        # raise ValueError("trying to free with non CVAL byteat")
    gbytearray__.free(int(byteat))

class UNINIT__:
    def __init__(self):
        pass

class CVAL__:
    def __init__(self, val, typename, is_auto=True, bytestart=None, size=None):
        self.typename = typename
        self.struct_spec = gbytearray__.get_struct_spec(typename)
        self.is_auto = is_auto
        self.is_uninit = isinstance(val, UNINIT__)

        if size is None:
            self.size = gbytearray__.get_size_of(typename)
        else:
            self.size = size

        if bytestart is None:
            self.bytestart = malloc__(self.size)
            if not self.is_uninit:
                self.setval(val)
        else:
            self.bytestart = bytestart

    def getval(self):
        if self.is_uninit:
            raise ValueError("attempt to read value from uninit variable")
        return struct.unpack(self.struct_spec, gbytearray__.arr[self.bytestart:self.bytestart+self.size])[0]

    def setval(self, val):
        self.is_uninit = False
        gbytearray__.set_at(self.bytestart, struct.pack(self.struct_spec, val))

    @staticmethod
    def create_from_typename(val, typename, is_auto=True, bytestart=None, size=None):
        structdef = gstructdefs__.get_type(typename)

        if structdef is not None:
            if size is not None and size != trnslt_sizeof(typename):
                sdefsize = structdef.size
                sdefname = str(structdef)
                raise ValueError(f"attempt to init compound value with non-matching size specified, sizeof({sdefname}) = {sdefsize}, but specified {size}")
            return structdef(val, is_auto, bytestart)

        arr_elemtypename = gstructdefs__.arr_elemtypenames.get(typename)

        if arr_elemtypename is not None:
            if bytestart is None:
                raise ValueError("attempt to deref ptr to an array and init copy of it")
            arrsize = trnslt_sizeof(typename)
            if size is not None and size != arrsize:
                raise ValueError(f"attempt to init array value with non-matching size specified, sizeof({typename}) = {arrsize}, but specified {size}")

            return CSIZEDARRAY__(val, arr_elemtypename, 
                arrsize/trnslt_sizeof(arr_elemtypename),
                is_auto, bytestart)

        if typename == "void*":
            return CPTR__(val, typename, is_auto, bytestart, size)
        return CVAL__(val, typename, is_auto, bytestart, size)


class CPTR__(CVAL__):
    def __init__(self, cval_containing_addr, elemtypename, is_auto=True, bytestart=None, size=None):
        self.is_uninit = isinstance(cval_containing_addr, UNINIT__)

        if not self.is_uninit:
            if not isinstance(cval_containing_addr, CVAL__):
                raise ValueError("attempt to take ptr to not cval")
            if cval_containing_addr.typename != "void*":
                raise ValueError("TODO: attempt to copy ptr value from non-void* cval")

        self.elemtypename = elemtypename
        self.elem_struct_spec = gbytearray__.get_struct_spec(elemtypename)
        self.elem_size = trnslt_sizeof(elemtypename)

        if not self.is_uninit:
            super().__init__(cval_containing_addr.getval(), "void*", is_auto, bytestart, size)
        else:
            super().__init__(cval_containing_addr, "void*", is_auto, bytestart, size)


    def deref_and_getval(self):
        ptrvalue = self.getval()
        return struct.unpack(self.elem_struct_spec, gbytearray__.arr[ptrvalue:ptrvalue + self.elem_size])[0]

    def deref_as_str(self):
        if self.elemtypename != "signed char":
            raise ValueError("attempt to use ptr to " + 
                self.elemtypename + " as a string")
        start = self.getval()
        end = gbytearray__.find_null_from(start)
        return gbytearray__.arr[start:end].decode('utf-8')

    def with_offset(self, offset):
        if not isinstance(offset, int):
            raise ValueError("attempt to add " + str(type(offset)) + " to a pointer")

        return CPTR__(
            CVAL__(
                self.getval() + offset * self.elem_size, 
                self.typename), 
            self.elemtypename)

    def __getitem__(self, key):
        if not isinstance(key, int):
            raise ValueError("attempt to index ptr with " + str(type(key)))
        return CVAL__.create_from_typename(
            None, 
            self.elemtypename, 
            True, 
            self.getval() + self.elem_size*key, 
            self.elem_size
        )


class CSIZEDARRAY__(CVAL__):
    def __init__(self, pylist, elemtypename, elem_count, is_auto=True, bytestart=None):
        is_pylist_str = False
        if not isinstance(pylist, list) and bytestart is None:
            if isinstance(pylist, str):
                is_pylist_str = True
            else:
                raise ValueError("attempt to create CSIZEDARRAY__ from " + str(type(pylist)))

        self.is_auto = is_auto

        # super().__init__(cval_containing_addr.getval(), "void*", is_auto, bytestart, size)

        if elem_count == None:
            elem_count = len(pylist)
        elif bytestart is None and elem_count < len(pylist):
            raise ValueError("attempt to slice off elements at the end of an array")

        self.typename = CSIZEDARRAY__.get_unique_name(
                elemtypename, elem_count)
        self.elemtypename = elemtypename
        self.elem_struct_spec = gbytearray__.get_struct_spec(elemtypename)
        self.elem_size = trnslt_sizeof(elemtypename)
        self.elem_count = elem_count

        # self.size = self.elem_size * self.elem_count
        self.size = trnslt_sizeof(self.typename)

        if bytestart is None:
            self.bytestart = gbytearray__.malloc(self.size)
        else:
            self.bytestart = bytestart
            return

        if is_pylist_str:
            self.init_from_str(pylist)
            return
        
        for elem_index in range(len(pylist)):
            elem = pylist[elem_index]
            elem_dst = self.bytestart + self.elem_size * elem_index
            
            if not isinstance(elem, CVAL__):
                raise ValueError("elem type of sized array must not be " + str(type(elem)) + ", but a CVAL__")
            # TODO: elem.size, if nested array, will be different
            #   because self.elem_size is going to be sizeof(void*)
            #   account for that
            if elem.size != self.elem_size:
                raise ValueError("inconsistent size of values in an array")

            gbytearray__.memcpy(elem_dst, elem.bytestart, self.elem_size)

        init_with_init_func = True

        # value initializing 
        if elem_count > len(pylist):
            gbytearray__.set_at(
                self.bytestart + len(pylist) * self.elem_size,
                bytearray((elem_count - len(pylist)) * self.elem_size)
            )

    def init_from_str(self, pylist):
        gbytearray__.set_at(self.bytestart, bytearray(pylist, "utf-8"))

    def getval(self):
        tup = (struct.unpack(self.elem_struct_spec*self.elem_count, gbytearray__.arr[self.bytestart:self.bytestart+self.size]))
        ret = bytearray()
        for ch in tup:
            ret += bytearray([ch])
        return ret.decode('utf-8')

    def decay(self):
        return CPTR__(CVAL__(self.bytestart, "void*"), self.elemtypename)

    def with_offset(self, offset):
        if not isinstance(offset, int):
            raise ValueError("attempt to add " + str(type(offset)) + " to a pointer")

        return self.decay().with_offset(offset)

    def __getitem__(self, key):
        return self.decay()[key]

    @staticmethod
    def get_unique_name(elemtypename, elem_count):
        name = "trnslt__sizedarr__" + elemtypename + "__" + str(int(elem_count)) + "__"
        if gstructdefs__.arr_elemtypenames.get(name) is None:
            raise ValueError(f"attempt to use arr {name} but it's not recorded in arr_elemtypenames")
        if gstructdefs__.arr_static_sizes.get(name) is None:
            raise ValueError(f"attempt to use arr {name} but it's not recorded in arr_static_sizes")

        return name


class CFUNCTION__(CPTR__):
    functions = []

    def __init__(self, cptr_containing_index, is_auto=True, bytestart=None, size=None):
        if not isinstance(cptr_containing_index, CPTR__):
            raise ValueError("ptr containing index is not cptr, but " + str(type(cptr_containing_index)))

        super().__init__(cptr_containing_index, cptr_containing_index.elemtypename, is_auto, bytestart, size)

    def __call__(self, *args, **kwargs):
        findex = self.getval()
        func = self.functions[findex]
        return func(*args, **kwargs)

    
    @classmethod
    def append_function(cls, fn):
        cls.functions.append(fn)
        ptr = CPTR__(CVAL__(len(cls.functions) - 1, "void*"), "int")
        return CFUNCTION__(ptr)


def trnslt_deref(lhs):
    if not isinstance(lhs, CPTR__):
        raise ValueError("attempt to dereference " + str(type(lhs)))
    return lhs[0]

def trnslt_ptr(lhs):
    return CPTR__(CVAL__(lhs.bytestart, "void*"), lhs.typename)

def trnslt_assign(lhs, rhs):
    if not isinstance(lhs, CVAL__):
        raise ValueError("LHS is not CVAL__")
    if not isinstance(rhs, CVAL__):
        raise ValueError("RHS is not CVAL__")
    
    if type(lhs) is not CPTR__ and type(lhs) is not CVAL__:
        if type(lhs) is not type(rhs):
            raise ValueError("attempt to init" + 
                str(type(lhs)) + " from " + str(type(rhs)))
            
        gbytearray__.memcpy(lhs.bytestart, rhs.bytestart, rhs.size)

        return lhs

    # TODO: some integer promotion ?
    val = rhs.getval()
    lhs.setval(val)
    return lhs

def trnslt_plus(lhs, rhs):
    if not isinstance(lhs, CVAL__):
        raise ValueError("LHS is not CVAL__")
    if not isinstance(rhs, CVAL__):
        raise ValueError("RHS is not CVAL__")

    if isinstance(lhs, CPTR__):
        return lhs.with_offset(rhs.getval())

    # TODO: account integer promotion for typename (do we need it?)
    lhsval = lhs.getval()
    rhsval = rhs.getval()
    # print("plus", type(lhsval), lhsval, type(rhsval), rhsval)
    return CVAL__(lhsval + rhsval, lhs.typename)

def trnslt_minus(lhs, rhs):
    return trnslt_plus(lhs, CVAL__(-rhs.getval()))

def trnslt_div(lhs, rhs):
    # TODO: int promotion
    return CVAL__(lhs.getval() / rhs.getval(), lhs.typename)

def trnslt_xor(lhs, rhs):
    # TODO: int promotion
    return CVAL__(lhs.getval() ^ rhs.getval(), lhs.typename)

def trnslt_mult(lhs, rhs):
    # TODO: int promotion
    return CVAL__(lhs.getval() * rhs.getval(), lhs.typename)

def trnslt_call(lhs, *args):
    # TODO
    return lhs(*args)

def trnslt_index(lhs, rhs):
    if not isinstance(rhs, CVAL__):
        raise ValueError("attempt to index with {type(rhs)}")

    return lhs[rhs.getval()]

def trnslt_arg(lhs):
    if isinstance(lhs, CPTR__):
        # return the pointer as is
        return lhs
    # decay
    if isinstance(lhs, CSIZEDARRAY__):
        return lhs.decay()
    if type(lhs) is not CVAL__:
        return gstructdefs__.get_type(lhs.typename)(lhs, True)
    # return copy
    return CVAL__(lhs.getval(), lhs.typename)

class FIELD_FACTORY__:
    def __init__(self, name, typename=None, typedesc=None, sizedarr_count=None, size=None):
        self.name = name
        self.typename = typename
        self.typedesc = typedesc
        self.sizedarr_count = sizedarr_count

        dummy_field = self.gen_new_field(0)
        if size is None:
            self.size = dummy_field.size
        else:
            self.size = size
        # self.struct_spec = dummy_field.struct_spec

    def gen_new_field(self, offset):
        typename = self.typename 
        typedesc = self.typedesc 
        sizedarr_count = self.sizedarr_count 

        if typedesc == "CVAL__":
            return CVAL__(UNINIT__(), typename, False, offset)
        elif typedesc == "CPTR__":
            # typename here as elemtypename
            return CPTR__(UNINIT__(), typename, False, offset)
        elif typedesc == "CSIZEDARRAY__":
            if sizedarr_count == None:
                raise ValueError("attempt to create csizedarray field without size")
            # typename here as elemtypename
            return CSIZEDARRAY__(UNINIT__(), typename, sizedarr_count, False, offset)
        
        structdef = gstructdefs__.get_type(typename)
        if structdef is not None:
            return structdef(None, False, offset)

        arr_elemtype = gstructdefs__.arr_elemtypenames.get(typename)
        if arr_elemtype is not None:
            arr_elemcount = gstructdefs__.arr_static_sizes.get(typename)
            if arr_elemcount is None:
                raise ValueError("array is accounted but no size")
            return CSIZEDARRAY__(
                None, arr_elemtype, arr_elemcount, False, offset)

        raise ValueError("attempt to create field, but no matching typedesc found for", typedesc)


def trnslt_get_new_init(captured_typename, *fielddescs):
    for desc in fielddescs:
        if not isinstance(desc, FIELD_FACTORY__):
            raise ValueError("trying to define structure with a list of" + str(type(field)) + " and not FIELD_FACTORY__")

    # def TRNSLT_STRUCT__ __init__(self, *args):
    def new_init(self, cstruct, is_auto = True, bytestart=None, *args):
        if cstruct is not None and len(args) != 0:
            raise ValueError("to init cstruct, provide either cstruct or args, not both")
        
        self.is_auto = is_auto
        self.is_uninit = False
        self.typename = captured_typename
        self.size = sum([ f.size for f in fielddescs ])

        if bytestart is not None:
            self.bytestart = bytestart
        else:
            self.bytestart = gbytearray__.malloc(self.size)


        # creating attributes for a new object
        # they may be already init if bytestart is specified,
        # but we still need to create at least attributes that
        # describe offsets into the structure
        field_offset = 0
        for i in range(len(fielddescs)):
            field = fielddescs[i].gen_new_field(self.bytestart + field_offset)
            if bytestart is not None:
                field.is_uninit = False

            setattr(self, fielddescs[i].name, field,)
            field_offset += fielddescs[i].size

        # if taken from some bytestart
        if bytestart is not None:
            return

        # setting all fields
        field_offset = 0
        for i in range(len(args)):
            # assigning to uninit var to preserve integer promotion
            field = None
            if cstruct is not None:
                field = getattr(cstruct, fielddescs[i].name)
            else:
                field = args[i]
                
            trnslt_assign(getattr(self, fielddescs[i].name), field)
            field_offset += fielddescs[i].size

        if cstruct is None:
            for i in range(len(args), len(fielddescs)):
                # TODO: zero init doesn't work sometimes
                #       so just rely on __getattr__ function to get fields
                setattr(
                    self, 
                    fielddescs[i].name, 
                    fielddescs[i].gen_new_field(self.bytestart + field_offset),
                )
                field = getattr(self, fielddescs[i].name)
                field.is_uninit = False
                gbytearray__.set_at(field.bytestart, bytearray(field.size))
            

    return new_init

def trnslt_sizeof(typename):
    primsize = gbytearray__.get_size_of(typename)
    if primsize is not None:
        return primsize

    structsize = gstructdefs__.static_sizes.get(typename)
    if structsize is not None:
        return structsize

    arrsize = gstructdefs__.arr_static_sizes.get(typename)
    if arrsize is not None:
        return arrsize

    raise ValueError(f"no size specified for {typename}")

class gstructdefs__:
    defs = {}
    static_sizes = {}

    arr_elemtypenames = {}
    arr_static_sizes = {}


    @staticmethod
    def new_structure_def(name, *args):
        struct_def = type(name, (CVAL__, ), { "__init__": trnslt_get_new_init(name, *args) })
        return struct_def

    @classmethod
    def account_new_structure_def(cls, name, *args):
        sdef = cls.new_structure_def(name, *args)
        cls.defs[name] = sdef
        cls.static_sizes[name] = sdef(None, True, 0).size
        return sdef

    @classmethod
    def account_new_array_def(cls, name, elemtypename, size):
        cls.arr_static_sizes[name] = trnslt_sizeof(elemtypename) * size
        cls.arr_elemtypenames[name] = elemtypename

    @classmethod
    def get_type(cls, name):
        return cls.defs.get(name)

def printf(fmt, *args):
    def norm(x):
        if type(x) is CVAL__:
            return x.getval()
        if type(x) is CPTR__:
            if x.elemtypename == "signed char":
                return x.deref_as_str()
        return x.getval()


    print(fmt.getval() % tuple([
        norm(arg)
        for arg in args
    ]), end='')
printf = CFUNCTION__.append_function(printf)
