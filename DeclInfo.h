#ifndef DECL_INFO_H_
#define DECL_INFO_H_

typedef struct {
    int is_pointer;
    // == 0 if !is_pointer but no size specified in decl
    int array_size;
} IndirectionLink;

typedef struct {
    IndirectionLink* items;
    int count;
    int cap;
} IndirectionArray;

typedef struct {
    IndirectionArray indirection;

    // usually, name of a variable
    char* text;
    // name of a basic type
    char* typename_text;
    int is_compound;
    // may be true only if is_compound == true
    int is_union;
} DeclInfo;

#define writeyyout(fmt, ...) \
do { \
    char* args_macroed[] = { __VA_ARGS__ }; \
    writeyyout_fn(fmt, sizeof(args_macroed)/sizeof(args_macroed[0]), ## __VA_ARGS__); \
    for(int i = 0; i < sizeof(args_macroed)/sizeof(args_macroed[0]); ++i) { \
        free(args_macroed[i]); \
    } \
} while(0)
void writeyyout_fn(const char fmt[], int count, ...);

#define writestr(str, fmt, ...) \
do { \
    char* args_macroed[] = { __VA_ARGS__ }; \
    sprintf(str, fmt, ## __VA_ARGS__); \
    for(int i = 0; i < sizeof(args_macroed)/sizeof(args_macroed[0]); ++i) { \
        free(args_macroed[i]); \
    } \
} while(0)
#endif // DECL_INFO_H_
