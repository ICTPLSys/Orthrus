add_library(masstree_vanilla_raw vanilla/closure.cpp)
target_compile_definitions(masstree_vanilla_raw PRIVATE NAMESPACE=raw)

add_library(masstree_vanilla_app vanilla/closure.cpp)
target_compile_definitions(masstree_vanilla_app PRIVATE NAMESPACE=app)

add_library(masstree_vanilla_val vanilla/closure.cpp)
target_compile_definitions(masstree_vanilla_val PRIVATE NAMESPACE=validator)

add_executable(masstree_vanilla vanilla/benchmark.cpp)
target_link_libraries(masstree_vanilla PRIVATE ${LIBS_disabled}
    masstree_vanilla_raw
    masstree_vanilla_app
    masstree_vanilla_val
)

add_executable(masstree_vanilla_mem vanilla/benchmark.cpp)
target_link_libraries(masstree_vanilla_mem PRIVATE ${LIBS_disabled} profile_mem
    masstree_orthrus_raw
    masstree_orthrus_app
    masstree_orthrus_val
)
target_compile_definitions(masstree_vanilla_mem PRIVATE PROFILE_MEM)

add_library(masstree_orthrus_raw orthrus/closure.cpp)
target_compile_definitions(masstree_vanilla_raw PRIVATE NAMESPACE=raw)

add_library(masstree_orthrus_app orthrus/closure.cpp)
target_compile_definitions(masstree_orthrus_app PRIVATE NAMESPACE=app)

add_library(masstree_orthrus_val orthrus/closure.cpp)
target_compile_definitions(masstree_orthrus_val PRIVATE NAMESPACE=validator)

add_executable(masstree_orthrus orthrus/benchmark.cpp)
target_link_libraries(masstree_orthrus PRIVATE ${LIBS}
    masstree_orthrus_raw
    masstree_orthrus_app
    masstree_orthrus_val
)

add_executable(masstree_orthrus_mem orthrus/benchmark.cpp)
target_link_libraries(masstree_orthrus_mem PRIVATE ${LIBS} profile_mem
    masstree_orthrus_raw
    masstree_orthrus_app
    masstree_orthrus_val
)
target_compile_definitions(masstree_orthrus_mem PRIVATE PROFILE_MEM)

add_executable(masstree_orthrus_profile orthrus/benchmark.cpp)
target_link_libraries(masstree_orthrus_profile PRIVATE ${LIBS_profile}
    masstree_orthrus_raw
    masstree_orthrus_app
    masstree_orthrus_val
)
target_compile_definitions(masstree_orthrus_profile PRIVATE PROFILE)

add_library(masstree_rbv_raw rbv/closure.cpp)
target_compile_definitions(masstree_rbv_raw PRIVATE NAMESPACE=raw)

add_library(masstree_rbv_app rbv/closure.cpp)
target_compile_definitions(masstree_rbv_app PRIVATE NAMESPACE=app)

add_library(masstree_rbv_val rbv/closure.cpp)
target_compile_definitions(masstree_rbv_val PRIVATE NAMESPACE=validator)

add_executable(masstree_rbv rbv/benchmark.cpp)
target_link_libraries(masstree_rbv PRIVATE ${LIBS_disabled}
    masstree_rbv_raw
    masstree_rbv_app
    masstree_rbv_val
)

add_executable(masstree_rbv_mem rbv/benchmark.cpp)
target_link_libraries(masstree_rbv_mem PRIVATE ${LIBS_disabled} profile_mem
    masstree_rbv_raw
    masstree_rbv_app
    masstree_rbv_val
)
target_compile_definitions(masstree_rbv_mem PRIVATE PROFILE_MEM)

add_executable(masstree_rbv_profile rbv/benchmark.cpp)
target_link_libraries(masstree_rbv_profile PRIVATE ${LIBS_disabled_profile}
    masstree_rbv_raw
    masstree_rbv_app
    masstree_rbv_val
)
target_compile_definitions(masstree_rbv_profile PRIVATE PROFILE)
