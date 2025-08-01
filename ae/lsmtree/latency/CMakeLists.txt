# ================ latency vs pXX ==================
function(add_latency_target NAME LIBLSMTREE)
    set(TARGET lsmtree_socket_latency_pXX_${NAME})
    add_executable(${TARGET} socket_latency_pXX_${NAME}.cpp)
    target_link_libraries(${TARGET} PRIVATE
        gflags::gflags
        ${LIBLSMTREE}
        ${LIBS}
    )
endfunction()

add_latency_target(vanilla   rawlsmtree)
add_latency_target(orthrus   lsmtree)
add_latency_target(rbv       rawlsmtree)

set(TARGET lsmtree_socket_latency_pXX_client)
add_executable(${TARGET} client.cpp)
target_link_libraries(${TARGET} PRIVATE
    gflags::gflags
    hdr_histogram
    ${LIBS_deps}
)
