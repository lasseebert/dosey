--
-- PostgreSQL database dump
--

-- Dumped from database version 18.3 (Debian 18.3-1.pgdg13+1)
-- Dumped by pg_dump version 18.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: citext; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;


--
-- Name: EXTENSION citext; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';


--
-- Name: diary_event_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.diary_event_type AS ENUM (
    'social',
    'meltdown',
    'meal',
    'wake_attempt',
    'put_to_bed',
    'other'
);


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: diary_days; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.diary_days (
    id uuid NOT NULL,
    date date NOT NULL,
    wake_time time(0) without time zone,
    medicine_time time(0) without time zone,
    sleep_time time(0) without time zone,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: diary_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.diary_events (
    id uuid NOT NULL,
    day_id uuid NOT NULL,
    event_type public.diary_event_type NOT NULL,
    text text,
    started_at_time time(0) without time zone,
    ended_at_time time(0) without time zone,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid NOT NULL,
    email public.citext NOT NULL,
    hashed_password character varying(255) NOT NULL,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: diary_days diary_days_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.diary_days
    ADD CONSTRAINT diary_days_pkey PRIMARY KEY (id);


--
-- Name: diary_events diary_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.diary_events
    ADD CONSTRAINT diary_events_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: diary_days_date_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX diary_days_date_index ON public.diary_days USING btree (date);


--
-- Name: diary_events_day_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX diary_events_day_id_index ON public.diary_events USING btree (day_id);


--
-- Name: diary_events_day_id_inserted_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX diary_events_day_id_inserted_at_index ON public.diary_events USING btree (day_id, inserted_at);


--
-- Name: users_email_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_email_index ON public.users USING btree (email);


--
-- Name: diary_events diary_events_day_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.diary_events
    ADD CONSTRAINT diary_events_day_id_fkey FOREIGN KEY (day_id) REFERENCES public.diary_days(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

INSERT INTO public."schema_migrations" (version) VALUES (20260815120000);
INSERT INTO public."schema_migrations" (version) VALUES (20260816120000);
INSERT INTO public."schema_migrations" (version) VALUES (20260816130000);
