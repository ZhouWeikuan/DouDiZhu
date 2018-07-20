/*
 ** luaproc API
 ** See Copyright Notice in luaproc.h
 */

#include <pthread.h>
#include <stdlib.h>
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

#include "LuaYunCheng.h"

/*************************************
 * execution status of lua processes *
 ************************************/

#define LUAPROC_STATUS_IDLE           0
#define LUAPROC_STATUS_READY          1
#define LUAPROC_STATUS_BLOCKED_SEND   2
#define LUAPROC_STATUS_BLOCKED_RECV   3
#define LUAPROC_STATUS_FINISHED       4

/*******************
 * structure types *
 ******************/

typedef struct stluaproc luaproc; /* lua process */

typedef struct stchannel channel; /* communication channel */

/* linked (fifo) list */
typedef struct stlist {
    luaproc *head;
    luaproc *tail;
    int nodes;
} list;

/***********************
 * function prototypes *
 **********************/

/* unlock access to a channel */
void luaproc_unlock_channel( channel *chan );

/* return a channel where a lua process is blocked at */
channel *luaproc_get_channel( luaproc *lp );

/* queue a lua process that tried to send a message */
void luaproc_queue_sender( luaproc *lp );

/* queue a lua process that tried to receive a message */
void luaproc_queue_receiver( luaproc *lp );

/* add a lua process to the recycle list */
void luaproc_recycle_insert( luaproc *lp );

/* return a lua process' status */
int luaproc_get_status( luaproc *lp );

/* set a lua process' status */
void luaproc_set_status( luaproc *lp, int status );

/* return a lua process' lua state */
lua_State *luaproc_get_state( luaproc *lp );

/* return the number of arguments expected by a lua process */
int luaproc_get_numargs( luaproc *lp );

/* set the number of arguments expected by a lua process */
void luaproc_set_numargs( luaproc *lp, int n );

/* initialize an empty list */
void list_init( list *l );

/* insert a lua process in a list */
void list_insert( list *l, luaproc *lp );

/* remove and return the first lua process in a list */
luaproc* list_remove( list *l );

/* return a list's node count */
int list_count( list *l );

/****************************************
 * scheduler functions return constants *
 ***************************************/

/* scheduler function return constants */
#define LUAPROC_SCHED_OK                 0
#define LUAPROC_SCHED_PTHREAD_ERROR     -1

/*************************************
 * default number of initial workers *
 ************************************/

/* scheduler default number of worker threads */
#define LUAPROC_SCHED_DEFAULT_WORKER_THREADS 1

/***********************
 * function prototypes *
 **********************/

/* initialize scheduler */
int sched_init( void );
/* join workers */
void sched_join_workers( void );
/* wait until there are no more active lua processes */
void sched_wait( void );
/* move process to ready queue (ie, schedule process) */
void sched_queue_proc( luaproc *lp );
/* increase active luaproc count */
void sched_inc_lpcount( void );
/* set number of active workers (creates and destroys accordingly) */
int sched_set_numworkers( int numworkers );
/* return the number of active workers */
int sched_get_numworkers( void );

#define FALSE 0
#define TRUE  !FALSE
#define LUAPROC_CHANNELS_TABLE "channeltb"
#define LUAPROC_SCHED_WORKERS_TABLE "workertb"

#define LUAPROC_RECYCLE_MAX 0


#if (LUA_VERSION_NUM >= 502)
#define luaproc_resume( L, from, nargs ) lua_resume( L, from, nargs )
#else
#define luaproc_resume( L, from, nargs ) lua_resume( L, nargs )
#endif


#if (LUA_VERSION_NUM == 501)

#define lua_pushglobaltable( L )    lua_pushvalue( L, LUA_GLOBALSINDEX )
#define luaL_newlib( L, funcs )     { lua_newtable( L ); \
    luaL_register( L, NULL, funcs ); }
#define isequal( L, a, b )          lua_equal( L, a, b )
#define requiref( L, modname, f, glob ) {\
    lua_pushcfunction( L, f ); /* push module load function */ \
    lua_pushstring( L, modname );  /* argument to module load function */ \
    lua_call( L, 1, 1 );  /* call 'f' to load module */ \
    /* register module in package.loaded table in case 'f' doesn't do so */ \
    lua_getfield( L, LUA_GLOBALSINDEX, LUA_LOADLIBNAME );\
    if ( lua_type( L, -1 ) == LUA_TTABLE ) {\
        lua_getfield( L, -1, "loaded" );\
        if ( lua_type( L, -1 ) == LUA_TTABLE ) {\
            lua_getfield( L, -1, modname );\
            if ( lua_type( L, -1 ) == LUA_TNIL ) {\
                lua_pushvalue( L, 1 );\
                lua_setfield( L, -3, modname );\
            }\
            lua_pop( L, 1 );\
        }\
        lua_pop( L, 1 );\
    }\
    lua_pop( L, 1 );\
    if ( glob ) { /* set global name? */ \
        lua_setglobal( L, modname );\
    } else {\
        lua_pop( L, 1 );\
    }\
}

#else

#define isequal( L, a, b )                 lua_compare( L, a, b, LUA_OPEQ )
#define requiref( L, modname, f, glob ) \
{ luaL_requiref( L, modname, f, glob ); lua_pop( L, 1 ); }

#endif

#if (LUA_VERSION_NUM >= 503)
#define dump( L, writer, data, strip )     lua_dump( L, writer, data, strip )
#define copynumber( Lto, Lfrom, i ) {\
    if ( lua_isinteger( Lfrom, i )) {\
        lua_pushinteger( Lto, lua_tonumber( Lfrom, i ));\
    } else {\
        lua_pushnumber( Lto, lua_tonumber( Lfrom, i ));\
    }\
}
#else
#define dump( L, writer, data, strip )     lua_dump( L, writer, data )
#define copynumber( Lto, Lfrom, i ) \
    lua_pushnumber( Lto, lua_tonumber( Lfrom, i ))
#endif

/********************
 * global variables *
 *******************/

/* ready process list */
list ready_lp_list;

/* ready process queue access mutex */
pthread_mutex_t mutex_sched = PTHREAD_MUTEX_INITIALIZER;

/* active luaproc count access mutex */
pthread_mutex_t mutex_lp_count = PTHREAD_MUTEX_INITIALIZER;

/* wake worker up conditional variable */
pthread_cond_t cond_wakeup_worker = PTHREAD_COND_INITIALIZER;

/* no active luaproc conditional variable */
pthread_cond_t cond_no_active_lp = PTHREAD_COND_INITIALIZER;

/* lua_State used to store workers hash table */
static lua_State *workerls = NULL;

int lpcount = 0;         /* number of active luaprocs */
int workerscount = 0;    /* number of active workers */
int destroyworkers = 0;  /* number of workers to destroy */

/***********************
 * register prototypes *
 ***********************/

static void sched_dec_lpcount( void );

/*******************************
 * worker thread main function *
 *******************************/

/* worker thread main function */
void *workermain( void *args ) {

    luaproc *lp;
    int procstat;

    /* main worker loop */
    while ( TRUE ) {
        /*
           wait until instructed to wake up (because there's work to do
           or because workers must be destroyed)
           */
        pthread_mutex_lock( &mutex_sched );
        while (( list_count( &ready_lp_list ) == 0 ) && ( destroyworkers <= 0 )) {
            pthread_cond_wait( &cond_wakeup_worker, &mutex_sched );
        }

        if ( destroyworkers > 0 ) {  /* check whether workers should be destroyed */

            destroyworkers--; /* decrease workers to be destroyed count */
            workerscount--; /* decrease active workers count */

            /* remove worker from workers table */
            lua_getglobal( workerls, LUAPROC_SCHED_WORKERS_TABLE );
            lua_pushlightuserdata( workerls, (void *)pthread_self( ));
            lua_pushnil( workerls );
            lua_rawset( workerls, -3 );
            lua_pop( workerls, 1 );

            pthread_cond_signal( &cond_wakeup_worker );  /* wake other workers up */
            pthread_mutex_unlock( &mutex_sched );
            pthread_exit( NULL );  /* destroy itself */
        }

        /* remove lua process from the ready queue */
        lp = list_remove( &ready_lp_list );
        pthread_mutex_unlock( &mutex_sched );

        /* execute the lua code specified in the lua process struct */
        procstat = luaproc_resume( luaproc_get_state( lp ), NULL,
                luaproc_get_numargs( lp ));
        /* reset the process argument count */
        luaproc_set_numargs( lp, 0 );

        /* has the lua process sucessfully finished its execution? */
        if ( procstat == 0 ) {
            luaproc_set_status( lp, LUAPROC_STATUS_FINISHED );  
            luaproc_recycle_insert( lp );  /* try to recycle finished lua process */
            sched_dec_lpcount();  /* decrease active lua process count */
        }

        /* has the lua process yielded? */
        else if ( procstat == LUA_YIELD ) {

            /* yield attempting to send a message */
            if ( luaproc_get_status( lp ) == LUAPROC_STATUS_BLOCKED_SEND ) {
                luaproc_queue_sender( lp );  /* queue lua process on channel */
                /* unlock channel */
                luaproc_unlock_channel( luaproc_get_channel( lp ));
            }

            /* yield attempting to receive a message */
            else if ( luaproc_get_status( lp ) == LUAPROC_STATUS_BLOCKED_RECV ) {
                luaproc_queue_receiver( lp );  /* queue lua process on channel */
                /* unlock channel */
                luaproc_unlock_channel( luaproc_get_channel( lp ));
            }

            /* yield on explicit coroutine.yield call */
            else { 
                /* re-insert the job at the end of the ready process queue */
                pthread_mutex_lock( &mutex_sched );
                list_insert( &ready_lp_list, lp );
                pthread_mutex_unlock( &mutex_sched );
            }
        }

        /* or was there an error executing the lua process? */
        else {
            /* print error message */
            fprintf( stderr, "close lua_State (error: %s)\n",
                    luaL_checkstring( luaproc_get_state( lp ), -1 ));
            lua_close( luaproc_get_state( lp ));  /* close lua state */
            sched_dec_lpcount();  /* decrease active lua process count */
        }
    }    
}

/***********************
 * auxiliary functions *
 **********************/

/* decrease active lua process count */
static void sched_dec_lpcount( void ) {
    pthread_mutex_lock( &mutex_lp_count );
    lpcount--;
    /* if count reaches zero, signal there are no more active processes */
    if ( lpcount == 0 ) {
        pthread_cond_signal( &cond_no_active_lp );
    }
    pthread_mutex_unlock( &mutex_lp_count );
}

/**********************
 * exported functions *
 **********************/

/* increase active lua process count */
void sched_inc_lpcount( void ) {
    pthread_mutex_lock( &mutex_lp_count );
    lpcount++;
    pthread_mutex_unlock( &mutex_lp_count );
}

/* local scheduler initialization */
int sched_init( void ) {

    int i;
    pthread_t worker;

    /* initialize ready process list */
    list_init( &ready_lp_list );

    /* initialize workers table and lua_State used to store it */
    workerls = luaL_newstate();
    lua_newtable( workerls );
    lua_setglobal( workerls, LUAPROC_SCHED_WORKERS_TABLE );

    /* get ready to access worker threads table */
    lua_getglobal( workerls, LUAPROC_SCHED_WORKERS_TABLE );

    /* create default number of initial worker threads */
    for ( i = 0; i < LUAPROC_SCHED_DEFAULT_WORKER_THREADS; i++ ) {

        if ( pthread_create( &worker, NULL, workermain, NULL ) != 0 ) {
            lua_pop( workerls, 1 ); /* pop workers table from stack */
            return LUAPROC_SCHED_PTHREAD_ERROR;
        }

        /* store worker thread id in a table */
        lua_pushlightuserdata( workerls, (void *)worker );
        lua_pushboolean( workerls, TRUE );
        lua_rawset( workerls, -3 );

        workerscount++; /* increase active workers count */
    }

    lua_pop( workerls, 1 ); /* pop workers table from stack */

    return LUAPROC_SCHED_OK;
}

/* set number of active workers */
int sched_set_numworkers( int numworkers ) {

    int i, delta;
    pthread_t worker;

    pthread_mutex_lock( &mutex_sched );

    /* calculate delta between existing workers and set number of workers */
    delta = numworkers - workerscount;

    /* create additional workers */
    if ( numworkers > workerscount ) {

        /* get ready to access worker threads table */
        lua_getglobal( workerls, LUAPROC_SCHED_WORKERS_TABLE );

        /* create additional workers */
        for ( i = 0; i < delta; i++ ) {

            if ( pthread_create( &worker, NULL, workermain, NULL ) != 0 ) {
                pthread_mutex_unlock( &mutex_sched );
                lua_pop( workerls, 1 ); /* pop workers table from stack */
                return LUAPROC_SCHED_PTHREAD_ERROR;
            }

            /* store worker thread id in a table */
            lua_pushlightuserdata( workerls, (void *)worker );
            lua_pushboolean( workerls, TRUE );
            lua_rawset( workerls, -3 );

            workerscount++; /* increase active workers count */
        }

        lua_pop( workerls, 1 ); /* pop workers table from stack */
    }
    /* destroy existing workers */
    else if ( numworkers < workerscount ) {
        destroyworkers = destroyworkers + numworkers;
    }

    pthread_mutex_unlock( &mutex_sched );

    return LUAPROC_SCHED_OK;
}

/* return the number of active workers */
int sched_get_numworkers( void ) {

    int numworkers;

    pthread_mutex_lock( &mutex_sched );
    numworkers = workerscount;
    pthread_mutex_unlock( &mutex_sched );

    return numworkers;
}

/* insert lua process in ready queue */
void sched_queue_proc( luaproc *lp ) {
    pthread_mutex_lock( &mutex_sched );
    list_insert( &ready_lp_list, lp );  /* add process to ready queue */
    /* set process status ready */
    luaproc_set_status( lp, LUAPROC_STATUS_READY );
    pthread_cond_signal( &cond_wakeup_worker );  /* wake worker up */
    pthread_mutex_unlock( &mutex_sched );
}

/* join worker threads (called when Lua exits). not joining workers causes a
   race condition since lua_close unregisters dynamic libs with dlclose and
   thus libpthreads can be unloaded while there are workers that are still 
   alive. */
void sched_join_workers( void ) {

    lua_State *L = luaL_newstate();
    const char *wtb = "workerstbcopy";

    /* wait for all running lua processes to finish */
    sched_wait();

    /* initialize new state and create table to copy worker ids */
    lua_newtable( L );
    lua_setglobal( L, wtb );
    lua_getglobal( L, wtb );

    pthread_mutex_lock( &mutex_sched );

    /* determine remaining active worker threads and copy their ids */
    lua_getglobal( workerls, LUAPROC_SCHED_WORKERS_TABLE );
    lua_pushnil( workerls );
    while ( lua_next( workerls, -2 ) != 0 ) {
        lua_pushlightuserdata( L, lua_touserdata( workerls, -2 ));
        lua_pushboolean( L, TRUE );
        lua_rawset( L, -3 );
        /* pop value, leave key for next iteration */
        lua_pop( workerls, 1 );
    }

    /* pop workers copy table name from stack */
    lua_pop( L, 1 );

    /* set all workers to be destroyed */
    destroyworkers = workerscount;

    /* wake workers up */
    pthread_cond_signal( &cond_wakeup_worker );
    pthread_mutex_unlock( &mutex_sched );

    /* join with worker threads (read ids from local table copy ) */
    lua_getglobal( L, wtb );
    lua_pushnil( L );
    while ( lua_next( L, -2 ) != 0 ) {
        pthread_join(( pthread_t )lua_touserdata( L, -2 ), NULL );
        /* pop value, leave key for next iteration */
        lua_pop( L, 1 );
    }
    lua_pop( L, 1 );

    lua_close( workerls );
    lua_close( L );
}

/* wait until there are no more active lua processes and active workers. */
void sched_wait( void ) {

    /* wait until there are not more active lua processes */
    pthread_mutex_lock( &mutex_lp_count );
    if( lpcount != 0 ) {
        pthread_cond_wait( &cond_no_active_lp, &mutex_lp_count );
    }
    pthread_mutex_unlock( &mutex_lp_count );

}


/********************
 * global variables *
 *******************/

/* channel list mutex */
static pthread_mutex_t mutex_channel_list = PTHREAD_MUTEX_INITIALIZER;

/* recycle list mutex */
static pthread_mutex_t mutex_recycle_list = PTHREAD_MUTEX_INITIALIZER;

/* recycled lua process list */
static list recycle_list;

/* maximum lua processes to recycle */
static int recyclemax = LUAPROC_RECYCLE_MAX;

/* lua_State used to store channel hash table */
static lua_State *chanls = NULL;

/* lua process used to wrap main state. allows main state to be queued in 
   channels when sending and receiving messages */
static luaproc mainlp;

/* main state matched a send/recv operation conditional variable */
pthread_cond_t cond_mainls_sendrecv = PTHREAD_COND_INITIALIZER;

/* main state communication mutex */
static pthread_mutex_t mutex_mainls = PTHREAD_MUTEX_INITIALIZER;

/***********************
 * register prototypes *
 ***********************/

static void luaproc_openlualibs( lua_State *L );
static int luaproc_create_newproc( lua_State *L );
static int luaproc_wait( lua_State *L );
static int luaproc_send( lua_State *L );
static int luaproc_receive( lua_State *L );
static int luaproc_create_channel( lua_State *L );
static int luaproc_destroy_channel( lua_State *L );
static int luaproc_set_numworkers( lua_State *L );
static int luaproc_get_numworkers( lua_State *L );
static int luaproc_recycle_set( lua_State *L );
LUALIB_API int luaopen_luaproc( lua_State *L );
static int luaproc_loadlib( lua_State *L ); 

/***********
 * structs *
 ***********/

/* lua process */
struct stluaproc {
    lua_State *lstate;
    int status;
    int args;
    channel *chan;
    luaproc *next;
};

/* communication channel */
struct stchannel {
    list send;
    list recv;
    pthread_mutex_t mutex;
    pthread_cond_t can_be_used;
};

/* luaproc function registration array */
static const struct luaL_Reg luaproc_funcs[] = {
    { "newproc", luaproc_create_newproc },
    { "wait", luaproc_wait },
    { "send", luaproc_send },
    { "receive", luaproc_receive },
    { "newchannel", luaproc_create_channel },
    { "delchannel", luaproc_destroy_channel },
    { "setnumworkers", luaproc_set_numworkers },
    { "getnumworkers", luaproc_get_numworkers },
    { "recycle", luaproc_recycle_set },
    { NULL, NULL }
};

/******************
 * list functions *
 ******************/

/* insert a lua process in a (fifo) list */
void list_insert( list *l, luaproc *lp ) {
    if ( l->head == NULL ) {
        l->head = lp;
    } else {
        l->tail->next = lp;
    }
    l->tail = lp;
    lp->next = NULL;
    l->nodes++;
}

/* remove and return the first lua process in a (fifo) list */
luaproc *list_remove( list *l ) {
    if ( l->head != NULL ) {
        luaproc *lp = l->head;
        l->head = lp->next;
        l->nodes--;
        return lp;
    } else {
        return NULL; /* if list is empty, return NULL */
    }
}

/* return a list's node count */
int list_count( list *l ) {
    return l->nodes;
}

/* initialize an empty list */
void list_init( list *l ) {
    l->head = NULL;
    l->tail = NULL;
    l->nodes = 0;
}

/*********************
 * channel functions *
 *********************/

/* create a new channel and insert it into channels table */
static channel *channel_create( const char *cname ) {

    channel *chan;

    /* get exclusive access to channels list */
    pthread_mutex_lock( &mutex_channel_list );

    /* create new channel and register its name */
    lua_getglobal( chanls, LUAPROC_CHANNELS_TABLE );
    chan = (channel *)lua_newuserdata( chanls, sizeof( channel ));
    lua_setfield( chanls, -2, cname );
    lua_pop( chanls, 1 );  /* remove channel table from stack */

    /* initialize channel struct */
    list_init( &chan->send );
    list_init( &chan->recv );
    pthread_mutex_init( &chan->mutex, NULL );
    pthread_cond_init( &chan->can_be_used, NULL );

    /* release exclusive access to channels list */
    pthread_mutex_unlock( &mutex_channel_list );

    return chan;
}

/*
   return a channel (if not found, return null).
   caller function MUST lock 'mutex_channel_list' before calling this function.
   */
static channel *channel_unlocked_get( const char *chname ) {

    channel *chan;

    lua_getglobal( chanls, LUAPROC_CHANNELS_TABLE );
    lua_getfield( chanls, -1, chname );
    chan = (channel *)lua_touserdata( chanls, -1 );
    lua_pop( chanls, 2 );  /* pop userdata and channel */

    return chan;
}

/*
   return a channel (if not found, return null) with its (mutex) lock set.
   caller function should unlock channel's (mutex) lock after calling this
   function.
   */
static channel *channel_locked_get( const char *chname ) {

    channel *chan;

    /* get exclusive access to channels list */
    pthread_mutex_lock( &mutex_channel_list );

    /*
       try to get channel and lock it; if lock fails, release external
       lock ('mutex_channel_list') to try again when signaled -- this avoids
       keeping the external lock busy for too long. during the release,
       the channel may be destroyed, so it must try to get it again.
       */
    while ((( chan = channel_unlocked_get( chname )) != NULL ) &&
            ( pthread_mutex_trylock( &chan->mutex ) != 0 )) {
        pthread_cond_wait( &chan->can_be_used, &mutex_channel_list );
    }

    /* release exclusive access to channels list */
    pthread_mutex_unlock( &mutex_channel_list );

    return chan;
}

/********************************
 * exported auxiliary functions *
 ********************************/

/* unlock access to a channel and signal it can be used */
void luaproc_unlock_channel( channel *chan ) {

    /* get exclusive access to channels list */
    pthread_mutex_lock( &mutex_channel_list );
    /* release exclusive access to operate on a particular channel */
    pthread_mutex_unlock( &chan->mutex );
    /* signal that a particular channel can be used */
    pthread_cond_signal( &chan->can_be_used );
    /* release exclusive access to channels list */
    pthread_mutex_unlock( &mutex_channel_list );

}

/* insert lua process in recycle list */
void luaproc_recycle_insert( luaproc *lp ) {

    /* get exclusive access to recycled lua processes list */
    pthread_mutex_lock( &mutex_recycle_list );

    /* is recycle list full? */
    if ( list_count( &recycle_list ) >= recyclemax ) {
        /* destroy state */
        lua_close( luaproc_get_state( lp ));
    } else {
        /* insert lua process in recycle list */
        list_insert( &recycle_list, lp );
    }

    /* release exclusive access to recycled lua processes list */
    pthread_mutex_unlock( &mutex_recycle_list );
}

/* queue a lua process that tried to send a message */
void luaproc_queue_sender( luaproc *lp ) {
    list_insert( &lp->chan->send, lp );
}

/* queue a lua process that tried to receive a message */
void luaproc_queue_receiver( luaproc *lp ) {
    list_insert( &lp->chan->recv, lp );
}

/********************************
 * internal auxiliary functions *
 ********************************/
static void luaproc_loadbuffer( lua_State *parent, luaproc *lp,
        const char *code, size_t len ) {

    /* load lua process' lua code */
    int ret = luaL_loadbuffer( lp->lstate, code, len, code );

    /* in case of errors, close lua_State and push error to parent */
    if ( ret != 0 ) {
        lua_pushstring( parent, lua_tostring( lp->lstate, -1 ));
        lua_close( lp->lstate );
        luaL_error( parent, lua_tostring( parent, -1 ));
    }
}

/* copies values between lua states' stacks */
static int luaproc_copyvalues( lua_State *Lfrom, lua_State *Lto ) {

    int i;
    int n = lua_gettop( Lfrom );
    const char *str;
    size_t len;

    /* ensure there is space in the receiver's stack */
    if ( lua_checkstack( Lto, n ) == 0 ) {
        lua_pushnil( Lto );
        lua_pushstring( Lto, "not enough space in the stack" );
        lua_pushnil( Lfrom );
        lua_pushstring( Lfrom, "not enough space in the receiver's stack" );
        return FALSE;
    }

    /* test each value's type and, if it's supported, copy value */
    for ( i = 2; i <= n; i++ ) {
        switch ( lua_type( Lfrom, i )) {
            case LUA_TBOOLEAN:
                lua_pushboolean( Lto, lua_toboolean( Lfrom, i ));
                break;
            case LUA_TNUMBER:
                copynumber( Lto, Lfrom, i );
                break;
            case LUA_TSTRING: {
                                  str = lua_tolstring( Lfrom, i, &len );
                                  lua_pushlstring( Lto, str, len );
                                  break;
                              }
            case LUA_TNIL:
                              lua_pushnil( Lto );
                              break;
            default: /* value type not supported: table, function, userdata, etc. */
                              lua_settop( Lto, 1 );
                              lua_pushnil( Lto );
                              lua_pushfstring( Lto, "failed to receive value of unsupported type "
                                      "'%s'", luaL_typename( Lfrom, i ));
                              lua_pushnil( Lfrom );
                              lua_pushfstring( Lfrom, "failed to send value of unsupported type "
                                      "'%s'", luaL_typename( Lfrom, i ));
                              return FALSE;
        }
    }
    return TRUE;
}

/* return the lua process associated with a given lua state */
static luaproc *luaproc_getself( lua_State *L ) {

    luaproc *lp;

    lua_getfield( L, LUA_REGISTRYINDEX, "LUAPROC_LP_UDATA" );
    lp = (luaproc *)lua_touserdata( L, -1 );
    lua_pop( L, 1 );

    return lp;
}

/* create new lua process */
static luaproc *luaproc_new( lua_State *L ) {

    luaproc *lp;
    lua_State *lpst = luaL_newstate();  /* create new lua state */

    /* store the lua process in its own lua state */
    lp = (luaproc *)lua_newuserdata( lpst, sizeof( struct stluaproc ));
    lua_setfield( lpst, LUA_REGISTRYINDEX, "LUAPROC_LP_UDATA" );
    luaproc_openlualibs( lpst );  /* load standard libraries and luaproc */
    /* register luaproc's own functions */
    requiref( lpst, "luaproc", luaproc_loadlib, TRUE );
    lp->lstate = lpst;  /* insert created lua state into lua process struct */
    
    lua_register(lpst, "robotFirstPlay",    light_robotFirstPlay);
    lua_register(lpst, "robotFollowCards",  light_robotFollowCards);

    lua_register(lpst, "getDirectPrompts",  light_getDirectPrompts);
    lua_register(lpst, "getFollowPrompts",  light_getFollowPrompts);

    lua_register(lpst, "calcPowerValue",  light_calcPowerValue);
    
    return lp;
}

/* join schedule workers (called before exiting Lua) */
static int luaproc_join_workers( lua_State *L ) {
    sched_join_workers();
    lua_close( chanls );
    return 0;
}

/* writer function for lua_dump */
static int luaproc_buff_writer( lua_State *L, const void *buff, size_t size, 
        void *ud ) {
    (void)L;
    luaL_addlstring((luaL_Buffer *)ud, (const char *)buff, size );
    return 0;
}

/* copies upvalues between lua states' stacks */
static int luaproc_copyupvalues( lua_State *Lfrom, lua_State *Lto, 
        int funcindex ) {

    int i = 1;
    const char *str;
    size_t len;

    /* test the type of each upvalue and, if it's supported, copy it */
    while ( lua_getupvalue( Lfrom, funcindex, i ) != NULL ) {
        switch ( lua_type( Lfrom, -1 )) {
            case LUA_TBOOLEAN:
                lua_pushboolean( Lto, lua_toboolean( Lfrom, -1 ));
                break;
            case LUA_TNUMBER:
                copynumber( Lto, Lfrom, -1 );
                break;
            case LUA_TSTRING: {
                                  str = lua_tolstring( Lfrom, -1, &len );
                                  lua_pushlstring( Lto, str, len );
                                  break;
                              }
            case LUA_TNIL:
                              lua_pushnil( Lto );
                              break;
                              /* if upvalue is a table, check whether it is the global environment
                                 (_ENV) from the source state Lfrom. in case so, push in the stack of
                                 the destination state Lto its own global environment to be set as the
                                 corresponding upvalue; otherwise, treat it as a regular non-supported
                                 upvalue type. */
            case LUA_TTABLE:
                              lua_pushglobaltable( Lfrom );
                              if ( isequal( Lfrom, -1, -2 )) {
                                  lua_pop( Lfrom, 1 );
                                  lua_pushglobaltable( Lto );
                                  break;
                              }
                              lua_pop( Lfrom, 1 );
                              /* FALLTHROUGH */
            default: /* value type not supported: table, function, userdata, etc. */
                              lua_pushnil( Lfrom );
                              lua_pushfstring( Lfrom, "failed to copy upvalue of unsupported type "
                                      "'%s'", luaL_typename( Lfrom, -2 ));
                              return FALSE;
        }
        lua_pop( Lfrom, 1 );
        if ( lua_setupvalue( Lto, 1, i ) == NULL ) {
            lua_pushnil( Lfrom );
            lua_pushstring( Lfrom, "failed to set upvalue" );
            return FALSE;
        }
        i++;
    }
    return TRUE;
}


/*********************
 * library functions *
 *********************/

/* set maximum number of lua processes in the recycle list */
static int luaproc_recycle_set( lua_State *L ) {

    luaproc *lp;

    /* validate parameter is a non negative number */
    lua_Integer max = luaL_checkinteger( L, 1 );
    luaL_argcheck( L, max >= 0, 1, "recycle limit must be positive" );

    /* get exclusive access to recycled lua processes list */
    pthread_mutex_lock( &mutex_recycle_list );

    recyclemax = max;  /* set maximum number */

    /* remove extra nodes and destroy each lua processes */
    while ( list_count( &recycle_list ) > recyclemax ) {
        lp = list_remove( &recycle_list );
        lua_close( lp->lstate );
    }
    /* release exclusive access to recycled lua processes list */
    pthread_mutex_unlock( &mutex_recycle_list );

    return 0;
}

/* wait until there are no more active lua processes */
static int luaproc_wait( lua_State *L ) {
    sched_wait();
    return 0;
}

/* set number of workers (creates or destroys accordingly) */
static int luaproc_set_numworkers( lua_State *L ) {

    /* validate parameter is a positive number */
    lua_Integer numworkers = luaL_checkinteger( L, -1 );
    luaL_argcheck( L, numworkers > 0, 1, "number of workers must be positive" );

    /* set number of threads; signal error on failure */
    if ( sched_set_numworkers( numworkers ) == LUAPROC_SCHED_PTHREAD_ERROR ) {
        luaL_error( L, "failed to create worker" );
    } 

    return 0;
}

/* return the number of active workers */
static int luaproc_get_numworkers( lua_State *L ) {
    lua_pushnumber( L, sched_get_numworkers( ));
    return 1;
}

/* create and schedule a new lua process */
static int luaproc_create_newproc( lua_State *L ) {

    size_t len;
    luaproc *lp;
    luaL_Buffer buff;
    const char *code;
    int d;
    int lt = lua_type( L, 1 );

    /* check function argument type - must be function or string; in case it is
       a function, dump it into a binary string */
    if ( lt == LUA_TFUNCTION ) {
        lua_settop( L, 1 );
        luaL_buffinit( L, &buff );
        d = dump( L, luaproc_buff_writer, &buff, FALSE );
        if ( d != 0 ) {
            lua_pushnil( L );
            lua_pushfstring( L, "error %d dumping function to binary string", d );
            return 2;
        }
        luaL_pushresult( &buff );
        lua_insert( L, 1 );
    } else if ( lt != LUA_TSTRING ) {
        lua_pushnil( L );
        lua_pushfstring( L, "cannot use '%s' to create a new process",
                luaL_typename( L, 1 ));
        return 2;
    }

    /* get pointer to code string */
    code = lua_tolstring( L, 1, &len );

    /* get exclusive access to recycled lua processes list */
    pthread_mutex_lock( &mutex_recycle_list );

    /* check if a lua process can be recycled */
    if ( recyclemax > 0 ) {
        lp = list_remove( &recycle_list );
        /* otherwise create a new lua process */
        if ( lp == NULL ) {
            lp = luaproc_new( L );
        }
    } else {
        lp = luaproc_new( L );
    }

    /* release exclusive access to recycled lua processes list */
    pthread_mutex_unlock( &mutex_recycle_list );

    /* init lua process */
    lp->status = LUAPROC_STATUS_IDLE;
    lp->args   = 0;
    lp->chan   = NULL;

    /* load code in lua process */
    luaproc_loadbuffer( L, lp, code, len );

    /* if lua process is being created from a function, copy its upvalues and
       remove dumped binary string from stack */
    if ( lt == LUA_TFUNCTION ) {
        if ( luaproc_copyupvalues( L, lp->lstate, 2 ) == FALSE ) {
            luaproc_recycle_insert( lp ); 
            return 2;
        }
        lua_pop( L, 1 );
    }

    sched_inc_lpcount();   /* increase active lua process count */
    sched_queue_proc( lp );  /* schedule lua process for execution */
    lua_pushboolean( L, TRUE );

    return 1;
}

/* send a message to a lua process */
static int luaproc_send( lua_State *L ) {

    int ret;
    channel *chan;
    luaproc *dstlp, *self;
    const char *chname = luaL_checkstring( L, 1 );

    chan = channel_locked_get( chname );
    /* if channel is not found, return an error to lua */
    if ( chan == NULL ) {
        lua_pushnil( L );
        lua_pushfstring( L, "channel '%s' does not exist", chname );
        return 2;
    }

    /* remove first lua process, if any, from channel's receive list */
    dstlp = list_remove( &chan->recv );

    if ( dstlp != NULL ) { /* found a receiver? */
        /* try to move values between lua states' stacks */
        ret = luaproc_copyvalues( L, dstlp->lstate );
        /* -1 because channel name is on the stack */
        dstlp->args = lua_gettop( dstlp->lstate ) - 1; 
        if ( dstlp->lstate == mainlp.lstate ) {
            /* if sending process is the parent (main) Lua state, unblock it */
            pthread_mutex_lock( &mutex_mainls );
            pthread_cond_signal( &cond_mainls_sendrecv );
            pthread_mutex_unlock( &mutex_mainls );
        } else {
            /* schedule receiving lua process for execution */
            sched_queue_proc( dstlp );
        }
        /* unlock channel access */
        luaproc_unlock_channel( chan );
        if ( ret == TRUE ) { /* was send successful? */
            lua_pushboolean( L, TRUE );
            return 1;
        } else { /* nil and error msg already in stack */
            return 2;
        }

    } else { 
        if ( L == mainlp.lstate ) {
            /* sending process is the parent (main) Lua state - block it */
            mainlp.chan = chan;
            luaproc_queue_sender( &mainlp );
            luaproc_unlock_channel( chan );
            pthread_mutex_lock( &mutex_mainls );
            pthread_cond_wait( &cond_mainls_sendrecv, &mutex_mainls );
            pthread_mutex_unlock( &mutex_mainls );
            return mainlp.args;
        } else {
            /* sending process is a standard luaproc - set status, block and yield */
            self = luaproc_getself( L );
            if ( self != NULL ) {
                self->status = LUAPROC_STATUS_BLOCKED_SEND;
                self->chan   = chan;
            }
            /* yield. channel will be unlocked by the scheduler */
            return lua_yield( L, lua_gettop( L ));
        }
    }
}

/* receive a message from a lua process */
static int luaproc_receive( lua_State *L ) {

    int ret, nargs;
    channel *chan;
    luaproc *srclp, *self;
    const char *chname = luaL_checkstring( L, 1 );

    /* get number of arguments passed to function */
    nargs = lua_gettop( L );

    chan = channel_locked_get( chname );
    /* if channel is not found, return an error to Lua */
    if ( chan == NULL ) {
        lua_pushnil( L );
        lua_pushfstring( L, "channel '%s' does not exist", chname );
        return 2;
    }

    /* remove first lua process, if any, from channels' send list */
    srclp = list_remove( &chan->send );

    if ( srclp != NULL ) {  /* found a sender? */
        /* try to move values between lua states' stacks */
        ret = luaproc_copyvalues( srclp->lstate, L );
        if ( ret == TRUE ) { /* was receive successful? */
            lua_pushboolean( srclp->lstate, TRUE );
            srclp->args = 1;
        } else {  /* nil and error_msg already in stack */
            srclp->args = 2;
        }
        if ( srclp->lstate == mainlp.lstate ) {
            /* if sending process is the parent (main) Lua state, unblock it */
            pthread_mutex_lock( &mutex_mainls );
            pthread_cond_signal( &cond_mainls_sendrecv );
            pthread_mutex_unlock( &mutex_mainls );
        } else {
            /* otherwise, schedule process for execution */
            sched_queue_proc( srclp );
        }
        /* unlock channel access */
        luaproc_unlock_channel( chan );
        /* disconsider channel name, async flag and any other args passed 
           to the receive function when returning its results */
        return lua_gettop( L ) - nargs; 

    } else {  /* otherwise test if receive was synchronous or asynchronous */
        if ( lua_toboolean( L, 2 )) { /* asynchronous receive */
            /* unlock channel access */
            luaproc_unlock_channel( chan );
            /* return an error */
            lua_pushnil( L );
            lua_pushfstring( L, "no senders waiting on channel '%s'", chname );
            return 2;
        } else { /* synchronous receive */
            if ( L == mainlp.lstate ) {
                /*  receiving process is the parent (main) Lua state - block it */
                mainlp.chan = chan;
                luaproc_queue_receiver( &mainlp );
                luaproc_unlock_channel( chan );
                pthread_mutex_lock( &mutex_mainls );
                pthread_cond_wait( &cond_mainls_sendrecv, &mutex_mainls );
                pthread_mutex_unlock( &mutex_mainls );
                return mainlp.args;
            } else {
                /* receiving process is a standard luaproc - set status, block and 
                   yield */
                self = luaproc_getself( L );
                if ( self != NULL ) {
                    self->status = LUAPROC_STATUS_BLOCKED_RECV;
                    self->chan   = chan;
                }
                /* yield. channel will be unlocked by the scheduler */
                return lua_yield( L, lua_gettop( L ));
            }
        }
    }
}

/* create a new channel */
static int luaproc_create_channel( lua_State *L ) {

    const char *chname = luaL_checkstring( L, 1 );

    channel *chan = channel_locked_get( chname );
    if (chan != NULL) {  /* does channel exist? */
        /* unlock the channel mutex locked by channel_locked_get */
        luaproc_unlock_channel( chan );
        /* return an error to lua */
        lua_pushnil( L );
        lua_pushfstring( L, "channel '%s' already exists", chname );
        return 2;
    } else {  /* create channel */
        channel_create( chname );
        lua_pushboolean( L, TRUE );
        return 1;
    }
}

/* destroy a channel */
static int luaproc_destroy_channel( lua_State *L ) {

    channel *chan;
    list *blockedlp;
    luaproc *lp;
    const char *chname = luaL_checkstring( L,  1 );

    /* get exclusive access to channels list */
    pthread_mutex_lock( &mutex_channel_list );

    /*
       try to get channel and lock it; if lock fails, release external
       lock ('mutex_channel_list') to try again when signaled -- this avoids
       keeping the external lock busy for too long. during this release,
       the channel may have been destroyed, so it must try to get it again.
       */
    while ((( chan = channel_unlocked_get( chname )) != NULL ) &&
            ( pthread_mutex_trylock( &chan->mutex ) != 0 )) {
        pthread_cond_wait( &chan->can_be_used, &mutex_channel_list );
    }

    if ( chan == NULL ) {  /* found channel? */
        /* release exclusive access to channels list */
        pthread_mutex_unlock( &mutex_channel_list );
        /* return an error to lua */
        lua_pushnil( L );
        lua_pushfstring( L, "channel '%s' does not exist", chname );
        return 2;
    }

    /* remove channel from table */
    lua_getglobal( chanls, LUAPROC_CHANNELS_TABLE );
    lua_pushnil( chanls );
    lua_setfield( chanls, -2, chname );
    lua_pop( chanls, 1 );

    pthread_mutex_unlock( &mutex_channel_list );

    /*
       wake up workers there are waiting to use the channel.
       they will not find the channel, since it was removed,
       and will not get this condition anymore.
       */
    pthread_cond_broadcast( &chan->can_be_used );

    /*
       dequeue lua processes waiting on the channel, return an error message
       to each of them indicating channel was destroyed and schedule them
       for execution (unblock them).
       */
    if ( chan->send.head != NULL ) {
        lua_pushfstring( L, "channel '%s' destroyed while waiting for receiver", 
                chname );
        blockedlp = &chan->send;
    } else {
        lua_pushfstring( L, "channel '%s' destroyed while waiting for sender", 
                chname );
        blockedlp = &chan->recv;
    }
    while (( lp = list_remove( blockedlp )) != NULL ) {
        /* return an error to each process */
        lua_pushnil( lp->lstate );
        lua_pushstring( lp->lstate, lua_tostring( L, -1 ));
        lp->args = 2;
        sched_queue_proc( lp ); /* schedule process for execution */
    }

    /* unlock channel mutex and destroy both mutex and condition */
    pthread_mutex_unlock( &chan->mutex );
    pthread_mutex_destroy( &chan->mutex );
    pthread_cond_destroy( &chan->can_be_used );

    lua_pushboolean( L, TRUE );
    return 1;
}

/***********************
 * get'ers and set'ers *
 ***********************/

/* return the channel where a lua process is blocked at */
channel *luaproc_get_channel( luaproc *lp ) {
    return lp->chan;
}

/* return a lua process' status */
int luaproc_get_status( luaproc *lp ) {
    return lp->status;
}

/* set lua a process' status */
void luaproc_set_status( luaproc *lp, int status ) {
    lp->status = status;
}

/* return a lua process' state */
lua_State *luaproc_get_state( luaproc *lp ) {
    return lp->lstate;
}

/* return the number of arguments expected by a lua process */
int luaproc_get_numargs( luaproc *lp ) {
    return lp->args;
}

/* set the number of arguments expected by a lua process */
void luaproc_set_numargs( luaproc *lp, int n ) {
    lp->args = n;
}

/**********************************
 * register structs and functions *
 **********************************/

static void luaproc_reglualib( lua_State *L, const char *name, 
        lua_CFunction f ) {
    lua_getglobal( L, "package" );
    lua_getfield( L, -1, "preload" );
    lua_pushcfunction( L, f );
    lua_setfield( L, -2, name );
    lua_pop( L, 2 );
}

static void luaproc_openlualibs( lua_State *L ) {
    requiref( L, "_G", luaopen_base, FALSE );
    requiref( L, "package", luaopen_package, TRUE );
    luaproc_reglualib( L, "io", luaopen_io );
    luaproc_reglualib( L, "os", luaopen_os );
    luaproc_reglualib( L, "table", luaopen_table );
    luaproc_reglualib( L, "string", luaopen_string );
    luaproc_reglualib( L, "math", luaopen_math );
    luaproc_reglualib( L, "debug", luaopen_debug );
#if (LUA_VERSION_NUM == 502)
    luaproc_reglualib( L, "bit32", luaopen_bit32 );
#endif
#if (LUA_VERSION_NUM >= 502)
    luaproc_reglualib( L, "coroutine", luaopen_coroutine );
#endif
#if (LUA_VERSION_NUM >= 503)
    luaproc_reglualib( L, "utf8", luaopen_utf8 );
#endif

}

LUALIB_API int luaopen_luaproc( lua_State *L ) {

    /* register luaproc functions */
    // luaL_newlib( L, luaproc_funcs );
    luaL_register(L, "luaproc", luaproc_funcs);

    /* wrap main state inside a lua process */
    mainlp.lstate = L;
    mainlp.status = LUAPROC_STATUS_IDLE;
    mainlp.args   = 0;
    mainlp.chan   = NULL;
    mainlp.next   = NULL;
    /* initialize recycle list */
    list_init( &recycle_list );
    /* initialize channels table and lua_State used to store it */
    chanls = luaL_newstate();
    lua_newtable( chanls );
    lua_setglobal( chanls, LUAPROC_CHANNELS_TABLE );
    /* create finalizer to join workers when Lua exits */
    lua_newuserdata( L, 0 );
    lua_setfield( L, LUA_REGISTRYINDEX, "LUAPROC_FINALIZER_UDATA" );
    luaL_newmetatable( L, "LUAPROC_FINALIZER_MT" );
    lua_pushliteral( L, "__gc" );
    lua_pushcfunction( L, luaproc_join_workers );
    lua_rawset( L, -3 );
    lua_pop( L, 1 );
    lua_getfield( L, LUA_REGISTRYINDEX, "LUAPROC_FINALIZER_UDATA" );
    lua_getfield( L, LUA_REGISTRYINDEX, "LUAPROC_FINALIZER_MT" );
    lua_setmetatable( L, -2 );
    lua_pop( L, 1 );
    /* initialize scheduler */
    if ( sched_init() == LUAPROC_SCHED_PTHREAD_ERROR ) {
        luaL_error( L, "failed to create worker" );
    }

    return 1;
}

static int luaproc_loadlib( lua_State *L ) {

    /* register luaproc functions */
    luaL_newlib( L, luaproc_funcs );

    return 1;
}

