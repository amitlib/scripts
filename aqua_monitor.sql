CREATE TABLE public.aqua_monitor (
    "timestamp" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    testname text NOT NULL,
    scanq_pending integer,
    scanq_progress integer,
    scanq_finished integer,
    scanq_failed integer,
    agents_connected integer,
    agents_disconnected integer,
    scanners_online integer,
    scanq_spm numeric,
    scanq_spmps numeric
);
