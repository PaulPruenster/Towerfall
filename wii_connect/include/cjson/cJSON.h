#ifndef WII_CONNECT_CJSON_COMPAT_H
#define WII_CONNECT_CJSON_COMPAT_H

#if defined(__has_include_next)
#if __has_include_next(<cjson/cJSON.h>)
#include_next <cjson/cJSON.h>
#define WII_CONNECT_USES_SYSTEM_CJSON_HEADER 1
#endif
#endif

#ifndef WII_CONNECT_USES_SYSTEM_CJSON_HEADER

#ifdef __cplusplus
extern "C" {
#endif

typedef struct cJSON {
	struct cJSON *next;
	struct cJSON *prev;
	struct cJSON *child;
	int type;
	char *valuestring;
	int valueint;
	double valuedouble;
	char *string;
} cJSON;

cJSON *cJSON_Parse(const char *value);
void cJSON_Delete(cJSON *item);
const char *cJSON_GetErrorPtr(void);
int cJSON_GetArraySize(const cJSON *array);
cJSON *cJSON_GetArrayItem(const cJSON *array, int index);
cJSON *cJSON_GetObjectItemCaseSensitive(const cJSON * const object, const char * const string);

#ifdef __cplusplus
}
#endif

#endif

#endif
