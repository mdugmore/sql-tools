BEGIN TRANSACTION 

------------------------------------------------------------------------- 
---------/* Enter a list of tables to be truncated */-------------------- 
------------------------------------------------------------------------- 

CREATE TABLE #truncatetables 
( 
 tablename VARCHAR(255) 
) 

INSERT INTO #truncatetables 
VALUES      ('TableName1'), 
            ('TableName2'), 
            ('TableName3') 

DECLARE @truncateTableName VARCHAR(255) 
DECLARE @dropAndCreateConstraintsTable TABLE 
  ( 
     tablename  NVARCHAR(255), 
     dropstmt   NVARCHAR(max), 
     createstmt NVARCHAR(max) 
  ) 
DECLARE @DropStatement NVARCHAR(max) 
DECLARE @RecreateStatement NVARCHAR(max) 

------------------------------------------------------------------------- 
---------/* Generate Create and Drop statements */----------------------- 
------------------------------------------------------------------------- 
INSERT @dropAndCreateConstraintsTable 
SELECT TableName = ForeignKeys.foreigntablename, 
       DropStmt = 'ALTER TABLE [' 
                  + ForeignKeys.foreigntableschema + '].[' 
                  + ForeignKeys.foreigntablename 
                  + '] DROP CONSTRAINT [' 
                  + ForeignKeys.foreignkeyname + ']; ', 
       CreateStmt = 'ALTER TABLE [' 
                    + ForeignKeys.foreigntableschema + '].[' 
                    + ForeignKeys.foreigntablename 
                    + '] WITH CHECK ADD CONSTRAINT [' 
                    + ForeignKeys.foreignkeyname 
                    + '] FOREIGN KEY([' 
                    + ForeignKeys.foreigntablecolumn 
                    + ']) REFERENCES [' 
                    + Schema_name(sys.objects.schema_id) + '].[' 
                    + sys.objects.[name] + ']([' 
                    + sys.columns.[name] + ']); ' 
FROM   sys.objects 
       INNER JOIN sys.columns 
               ON ( sys.columns.[object_id] = sys.objects.[object_id] ) 
       INNER JOIN (SELECT sys.foreign_keys.[name]                      AS 
                          ForeignKeyName, 
                          Schema_name(sys.objects.schema_id)           AS 
              ForeignTableSchema, 
                          sys.objects.[name]                           AS 
              ForeignTableName, 
                          sys.columns.[name]                           AS 
              ForeignTableColumn, 
                          sys.foreign_keys.referenced_object_id        AS 
              referenced_object_id, 
                          sys.foreign_key_columns.referenced_column_id AS 
              referenced_column_id 
                   FROM   sys.foreign_keys 
                          INNER JOIN sys.foreign_key_columns 
                                  ON ( 
                          sys.foreign_key_columns.constraint_object_id = 
                          sys.foreign_keys.[object_id] ) 
                          INNER JOIN sys.objects 
                                  ON ( sys.objects.[object_id] = 
                                       sys.foreign_keys.parent_object_id 
                                     ) 
                          INNER JOIN sys.columns 
                                  ON ( sys.columns.[object_id] = 
                                       sys.objects.[object_id] ) 
                                     AND ( sys.columns.column_id = 
sys.foreign_key_columns.parent_column_id )) 
ForeignKeys 
ON ( ForeignKeys.referenced_object_id = sys.objects.[object_id] ) 
AND ( ForeignKeys.referenced_column_id = sys.columns.column_id ) 
WHERE  ( sys.objects.[type] = 'U' ) 
       AND ( sys.objects.[name] NOT IN ( 'sysdiagrams' ) ) 

------------------------------------------------------------------------- 
-------------------/* Run Drop Constraints */---------------------------- 
------------------------------------------------------------------------- 
DECLARE cur1 CURSOR read_only FOR 
  SELECT dropstmt 
  FROM   @dropAndCreateConstraintsTable 

OPEN cur1 

FETCH next FROM cur1 INTO @DropStatement 

WHILE @@FETCH_STATUS = 0 
  BEGIN 
      PRINT 'Dropping constraints: Executing ' 
            + @DropStatement 

      EXECUTE Sp_executesql 
        @DropStatement 

      FETCH next FROM cur1 INTO @DropStatement 
  END 

CLOSE cur1 

DEALLOCATE cur1 

------------------------------------------------------------------------- 
-----------/* Loop through tables to truncate them */-------------------- 
------------------------------------------------------------------------- 
DECLARE tablescur CURSOR read_only FOR 
  SELECT tablename 
  FROM   #truncatetables 

OPEN tablescur 

FETCH next FROM tablescur INTO @truncateTableName 

WHILE @@FETCH_STATUS = 0 
  BEGIN 
      PRINT 'Processing ' + @truncateTableName 

      -------------------------------------------------------------------------------- 
      /* Truncate table in the database in dbo schema*/ 
      DECLARE @DeleteTableStatement NVARCHAR(max) = 'TRUNCATE TABLE [dbo].[' 
        + @truncateTableName + ']' 

      PRINT 'Truncating table with: ' 
            + @DeleteTableStatement 

      EXECUTE Sp_executesql 
        @DeleteTableStatement 

      FETCH next FROM tablescur INTO @truncateTableName 
  END 

CLOSE tablescur 

DEALLOCATE tablescur 

------------------------------------------------------------------------- 
-------------/* Recreating foreign key constraints */-------------------- 
------------------------------------------------------------------------- 
DECLARE cur3 CURSOR read_only FOR 
  SELECT createstmt 
  FROM   @dropAndCreateConstraintsTable 

OPEN cur3 

FETCH next FROM cur3 INTO @RecreateStatement 

WHILE @@FETCH_STATUS = 0 
  BEGIN 
      PRINT 'Recreating FK constraint with: ' 
            + @RecreateStatement 

      EXECUTE Sp_executesql 
        @RecreateStatement 

      FETCH next FROM cur3 INTO @RecreateStatement 
  END 

CLOSE cur3 

DEALLOCATE cur3 

DROP TABLE #truncatetables 

PRINT 'Completed succesfully' 

ROLLBACK TRANSACTION 